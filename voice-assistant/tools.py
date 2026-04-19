"""
tools.py - Async Mac task-executor tools for the nio voice assistant.

Each tool is an async function that returns a plain string result (success
message or content).  Errors are caught and returned as descriptive strings
so the LLM can relay them to the user without crashing the pipeline.

Also exports TOOLS_SCHEMA – an OpenAI-compatible function-calling schema list
that is injected into the LLM system context.
"""

from __future__ import annotations

import asyncio
import datetime
import json
import os
import re
import shutil
import subprocess
import sys
import textwrap
import urllib.parse
from pathlib import Path

import aiohttp

import config

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _truncate(text: str, max_chars: int = 4000) -> str:
    """Truncate long text and append an ellipsis note."""
    if len(text) <= max_chars:
        return text
    return text[:max_chars] + f"\n\n… [内容已截断，共 {len(text)} 字符]"


async def _run_subprocess(args: list[str], timeout: int = 30) -> tuple[int, str, str]:
    """Run a subprocess asynchronously and return (returncode, stdout, stderr)."""
    proc = await asyncio.create_subprocess_exec(
        *args,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    try:
        stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=timeout)
    except asyncio.TimeoutError:
        proc.kill()
        await proc.communicate()
        return -1, "", f"命令超时（{timeout}秒）"
    return proc.returncode, stdout.decode("utf-8", errors="replace"), stderr.decode("utf-8", errors="replace")


# ---------------------------------------------------------------------------
# Tool 1: open_app
# ---------------------------------------------------------------------------

async def open_app(app_name: str) -> str:
    """
    Open a macOS application by name.

    Tries three strategies in order:
      1. `open -a <AppName>` — direct open by app bundle name
      2. AppleScript `tell application "<AppName>" to activate`
      3. Spotlight search via `mdfind` + `open`
    """
    if not app_name or not app_name.strip():
        return "错误：请提供应用程序名称。"

    name = app_name.strip()

    # Strategy 1: open -a
    rc, out, err = await _run_subprocess(["open", "-a", name])
    if rc == 0:
        return f"已打开应用「{name}」。"

    # Strategy 2: AppleScript activate
    script = f'tell application "{name}" to activate'
    rc2, _, err2 = await _run_subprocess(["osascript", "-e", script])
    if rc2 == 0:
        return f"已通过 AppleScript 激活「{name}」。"

    # Strategy 3: mdfind fallback
    rc3, paths, _ = await _run_subprocess(
        ["mdfind", "-onlyin", "/Applications", f"kMDItemDisplayName == '*{name}*'cdw"]
    )
    if rc3 == 0 and paths.strip():
        first_path = paths.strip().splitlines()[0]
        rc4, _, _ = await _run_subprocess(["open", first_path])
        if rc4 == 0:
            return f"已打开「{first_path}」。"

    return f"无法打开应用「{name}」。错误信息：{err.strip() or err2.strip()}。请确认应用名称是否正确，或者应用是否已安装。"


# ---------------------------------------------------------------------------
# Tool 2: run_command
# ---------------------------------------------------------------------------

# Commands that are explicitly blocked for safety
_BLOCKED_PATTERNS = [
    r"rm\s+-[rRf]*f",        # rm -rf / rm -f
    r">\s*/dev/",             # overwrite device files
    r"mkfs",                  # format disk
    r"dd\s+if=",              # raw disk write
    r"sudo\s+rm",
    r":\(\)\{.*\}",           # fork bomb
    r"base64.*\|.*sh",        # encoded shell execution
    r"curl.*\|\s*(ba)?sh",    # curl pipe to shell
    r"wget.*\|\s*(ba)?sh",
]

_BLOCKED_RE = re.compile("|".join(_BLOCKED_PATTERNS), re.IGNORECASE)


async def run_command(command: str) -> str:
    """
    Execute a shell command safely in a subprocess and return its output.

    Dangerous patterns (e.g. rm -rf, mkfs) are blocked.
    Output is capped at ~4 000 characters.
    """
    if not command or not command.strip():
        return "错误：请提供要执行的命令。"

    cmd = command.strip()

    if _BLOCKED_RE.search(cmd):
        return f"安全限制：命令「{cmd}」包含危险操作，已被阻止执行。"

    proc = await asyncio.create_subprocess_shell(
        cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    try:
        stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=60)
    except asyncio.TimeoutError:
        proc.kill()
        await proc.communicate()
        return f"命令执行超时（60秒）：{cmd}"

    rc = proc.returncode
    out = stdout.decode("utf-8", errors="replace").strip()
    err = stderr.decode("utf-8", errors="replace").strip()

    if rc == 0:
        result = out if out else "命令执行成功（无输出）。"
    else:
        result = f"命令以状态码 {rc} 退出。\n输出：{out}\n错误：{err}"

    return _truncate(result)


# ---------------------------------------------------------------------------
# Tool 3: read_book
# ---------------------------------------------------------------------------

async def read_book(query: str) -> str:
    """
    Search for text files or PDFs matching *query* under BOOKS_DIR and return
    their content.

    Search is case-insensitive and matches filename or directory name.
    Plain text files are read directly.  PDFs are extracted via `pdftotext`
    (poppler) if available, otherwise the first few KB are returned as raw
    bytes info.
    """
    if not query or not query.strip():
        return "错误：请提供搜索关键词。"

    books_dir = config.BOOKS_DIR
    if not books_dir.exists():
        return f"书籍目录不存在：{books_dir}"

    q = query.strip().lower()

    # Collect candidate files
    candidates: list[Path] = []
    for ext in ("*.txt", "*.md", "*.pdf", "*.epub", "*.rst"):
        for p in books_dir.rglob(ext):
            if q in p.name.lower() or q in str(p.parent).lower():
                candidates.append(p)

    if not candidates:
        # Broaden: search inside text files for the query string
        for ext in ("*.txt", "*.md", "*.rst"):
            for p in books_dir.rglob(ext):
                try:
                    text = p.read_text(encoding="utf-8", errors="ignore")
                    if q in text.lower():
                        candidates.append(p)
                except OSError:
                    continue

    if not candidates:
        return f"在「{books_dir}」中未找到与「{query}」相关的文件。"

    target = candidates[0]

    # Read content
    if target.suffix.lower() == ".pdf":
        if shutil.which("pdftotext"):
            rc, out, err = await _run_subprocess(["pdftotext", str(target), "-"])
            if rc == 0 and out.strip():
                return _truncate(f"文件：{target.name}\n\n{out.strip()}")
        return f"找到 PDF 文件「{target.name}」，但系统未安装 pdftotext，无法提取文字内容。可以用 `brew install poppler` 安装。"

    try:
        content = target.read_text(encoding="utf-8", errors="ignore")
        return _truncate(f"文件：{target.name}\n路径：{target}\n\n{content}")
    except OSError as exc:
        return f"读取文件时出错：{exc}"


# ---------------------------------------------------------------------------
# Tool 4: get_weather
# ---------------------------------------------------------------------------

async def get_weather(location: str) -> str:
    """
    Fetch current weather for *location* using the free wttr.in JSON API.
    No API key required.
    """
    if not location or not location.strip():
        return "错误：请提供城市或地点名称。"

    loc = location.strip()
    encoded = urllib.parse.quote(loc)
    url = f"https://wttr.in/{encoded}?format=j1&lang=zh"

    try:
        async with aiohttp.ClientSession(
            timeout=aiohttp.ClientTimeout(total=15)
        ) as session:
            async with session.get(url, headers={"Accept": "application/json"}) as resp:
                if resp.status != 200:
                    return f"天气查询失败，HTTP 状态码：{resp.status}。"
                data = await resp.json(content_type=None)
    except aiohttp.ClientError as exc:
        return f"网络请求失败：{exc}"
    except Exception as exc:
        return f"天气查询出错：{exc}"

    try:
        current = data["current_condition"][0]
        weather_desc = current["weatherDesc"][0]["value"]
        temp_c = current["temp_C"]
        feels_like = current["FeelsLikeC"]
        humidity = current["humidity"]
        wind_kmph = current["windspeedKmph"]
        visibility = current["visibility"]

        nearest = data.get("nearest_area", [{}])[0]
        area_name = nearest.get("areaName", [{}])[0].get("value", loc)
        country = nearest.get("country", [{}])[0].get("value", "")

        # Tomorrow forecast
        forecast_tomorrow = ""
        if len(data.get("weather", [])) >= 2:
            tmr = data["weather"][1]
            tmr_desc = tmr["hourly"][4]["weatherDesc"][0]["value"]
            tmr_max = tmr["maxtempC"]
            tmr_min = tmr["mintempC"]
            forecast_tomorrow = f"\n明天：{tmr_desc}，{tmr_min}~{tmr_max}℃"

        result = (
            f"{area_name}{'，' + country if country else ''} 当前天气\n"
            f"天气：{weather_desc}\n"
            f"气温：{temp_c}℃（体感 {feels_like}℃）\n"
            f"湿度：{humidity}%\n"
            f"风速：{wind_kmph} 公里/小时\n"
            f"能见度：{visibility} 公里"
            f"{forecast_tomorrow}"
        )
        return result
    except (KeyError, IndexError) as exc:
        return f"解析天气数据失败：{exc}。原始数据片段：{str(data)[:300]}"


# ---------------------------------------------------------------------------
# Tool 5: search_web
# ---------------------------------------------------------------------------

# Simple DuckDuckGo HTML scraper – no API key required
_DDG_URL = "https://html.duckduckgo.com/html/"
_DDG_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
}


def _strip_html(html: str) -> str:
    """Very lightweight HTML tag stripper."""
    text = re.sub(r"<[^>]+>", " ", html)
    text = re.sub(r"&nbsp;", " ", text)
    text = re.sub(r"&amp;", "&", text)
    text = re.sub(r"&lt;", "<", text)
    text = re.sub(r"&gt;", ">", text)
    text = re.sub(r"&quot;", '"', text)
    text = re.sub(r"\s{2,}", " ", text)
    return text.strip()


async def search_web(query: str) -> str:
    """
    Search the web via DuckDuckGo HTML (no API key) and return the top results
    as plain text (title + snippet + URL).
    """
    if not query or not query.strip():
        return "错误：请提供搜索关键词。"

    q = query.strip()
    payload = {"q": q, "b": "", "kl": "cn-zh"}

    try:
        async with aiohttp.ClientSession(
            timeout=aiohttp.ClientTimeout(total=20)
        ) as session:
            async with session.post(
                _DDG_URL, data=payload, headers=_DDG_HEADERS
            ) as resp:
                if resp.status != 200:
                    return f"搜索失败，HTTP 状态码：{resp.status}。"
                html = await resp.text()
    except aiohttp.ClientError as exc:
        return f"网络请求失败：{exc}"

    # Extract result blocks
    # Each result is wrapped in <div class="result__body">
    result_blocks = re.findall(
        r'class="result__title".*?</a>.*?class="result__snippet"(.*?)</a>',
        html,
        re.DOTALL,
    )

    # Fallback: grab all result__a links + snippets
    titles = re.findall(r'class="result__a"[^>]*>(.*?)</a>', html, re.DOTALL)
    snippets = re.findall(r'class="result__snippet"[^>]*>(.*?)</a>', html, re.DOTALL)
    urls = re.findall(r'class="result__url"[^>]*>(.*?)</span>', html, re.DOTALL)

    if not titles:
        return f"未找到关于「{q}」的搜索结果。可能触发了反爬机制，请稍后重试。"

    lines: list[str] = [f"搜索结果：{q}\n"]
    limit = min(5, len(titles))
    for i in range(limit):
        title = _strip_html(titles[i]).strip()
        snippet = _strip_html(snippets[i]).strip() if i < len(snippets) else ""
        url = _strip_html(urls[i]).strip() if i < len(urls) else ""
        lines.append(f"{i + 1}. {title}")
        if snippet:
            lines.append(f"   {snippet}")
        if url:
            lines.append(f"   🔗 {url}")
        lines.append("")

    return _truncate("\n".join(lines))


# ---------------------------------------------------------------------------
# Tool 6: generate_report
# ---------------------------------------------------------------------------

async def generate_report(topic: str, content: str) -> str:
    """
    Generate a Markdown report file from *topic* and *content*, saving it to
    REPORTS_DIR.  Returns the absolute path of the saved file.
    """
    if not topic or not topic.strip():
        return "错误：请提供报告主题。"

    topic_clean = topic.strip()
    content_clean = content.strip() if content else ""

    # Build file name from topic + timestamp
    ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    safe_name = re.sub(r"[^\w\u4e00-\u9fff\-]", "_", topic_clean)[:60]
    filename = f"{ts}_{safe_name}.md"
    filepath = config.REPORTS_DIR / filename

    now_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    markdown = textwrap.dedent(f"""\
        # {topic_clean}

        > 生成时间：{now_str}
        > 由 nio 语音助手自动生成

        ---

        {content_clean}

        ---
        *本报告由 nio 语音助手生成*
    """)

    try:
        filepath.write_text(markdown, encoding="utf-8")
    except OSError as exc:
        return f"保存报告失败：{exc}"

    # Try to open Finder to the reports directory
    await _run_subprocess(["open", str(config.REPORTS_DIR)])

    return f"报告已保存至：{filepath}\n\n{markdown[:500]}{'…' if len(markdown) > 500 else ''}"


# ---------------------------------------------------------------------------
# Tool dispatcher
# ---------------------------------------------------------------------------

TOOL_FUNCTIONS: dict[str, callable] = {
    "open_app": open_app,
    "run_command": run_command,
    "read_book": read_book,
    "get_weather": get_weather,
    "search_web": search_web,
    "generate_report": generate_report,
}


async def dispatch_tool(name: str, arguments: dict) -> str:
    """
    Look up and call a tool by name with the given arguments dict.
    Returns the string result or an error message.
    """
    fn = TOOL_FUNCTIONS.get(name)
    if fn is None:
        return f"未知工具：{name}"
    try:
        return await fn(**arguments)
    except TypeError as exc:
        return f"工具参数错误 ({name}): {exc}"
    except Exception as exc:
        return f"工具执行异常 ({name}): {exc}"


# ---------------------------------------------------------------------------
# OpenAI function-calling schema
# ---------------------------------------------------------------------------

TOOLS_SCHEMA: list[dict] = [
    {
        "type": "function",
        "function": {
            "name": "open_app",
            "description": "在 macOS 上打开指定的应用程序。例如：Safari、微信、Terminal、VS Code、Spotify 等。",
            "parameters": {
                "type": "object",
                "properties": {
                    "app_name": {
                        "type": "string",
                        "description": "应用程序的名称，例如 'Safari'、'微信'、'Terminal'、'Visual Studio Code'",
                    }
                },
                "required": ["app_name"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "run_command",
            "description": "在 macOS 终端执行 shell 命令并返回输出结果。可用于查询系统信息、文件操作、运行脚本等。危险命令（如 rm -rf）会被拦截。",
            "parameters": {
                "type": "object",
                "properties": {
                    "command": {
                        "type": "string",
                        "description": "要执行的 shell 命令，例如 'ls ~/Documents' 或 'date'",
                    }
                },
                "required": ["command"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "read_book",
            "description": "在用户的文档目录中搜索并读取文本文件或 PDF 的内容。适用于查阅本地书籍、笔记、文档。",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "搜索关键词，用于匹配文件名或文件内容，例如 '三体' 或 '项目方案'",
                    }
                },
                "required": ["query"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_weather",
            "description": "查询指定城市或地点的实时天气情况，包括温度、湿度、风速和明日预报。",
            "parameters": {
                "type": "object",
                "properties": {
                    "location": {
                        "type": "string",
                        "description": "城市或地点名称，支持中英文，例如 '上海'、'Beijing'、'New York'",
                    }
                },
                "required": ["location"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "search_web",
            "description": "通过 DuckDuckGo 搜索互联网，获取最新信息、新闻、知识等。无需 API 密钥。",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "搜索关键词或问题，例如 '2024年诺贝尔奖得主' 或 'Python asyncio 教程'",
                    }
                },
                "required": ["query"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "generate_report",
            "description": "根据给定主题和内容生成 Markdown 格式的报告文件并保存到本地，同时在 Finder 中打开保存目录。",
            "parameters": {
                "type": "object",
                "properties": {
                    "topic": {
                        "type": "string",
                        "description": "报告主题或标题，例如 '2024年第三季度销售分析'",
                    },
                    "content": {
                        "type": "string",
                        "description": "报告正文内容，支持 Markdown 格式",
                    },
                },
                "required": ["topic", "content"],
            },
        },
    },
]
