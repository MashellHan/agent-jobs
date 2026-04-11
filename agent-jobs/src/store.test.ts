import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { readFileSync, writeFileSync, existsSync, mkdirSync, renameSync } from "fs";
import { loadHiddenIds, addHiddenId, removeRegisteredJob, setRegisteredJobStatus, killProcess } from "./store.js";

// Mock fs module
vi.mock("fs", () => ({
  readFileSync: vi.fn(),
  writeFileSync: vi.fn(),
  existsSync: vi.fn(),
  mkdirSync: vi.fn(),
  renameSync: vi.fn(),
  execFile: vi.fn(),
}));

vi.mock("child_process", () => ({
  execFile: vi.fn(),
}));

vi.mock("os", () => ({
  homedir: vi.fn(() => "/mock-home"),
}));

const mockReadFileSync = vi.mocked(readFileSync);
const mockWriteFileSync = vi.mocked(writeFileSync);
const mockExistsSync = vi.mocked(existsSync);
const mockMkdirSync = vi.mocked(mkdirSync);
const mockRenameSync = vi.mocked(renameSync);

beforeEach(() => {
  vi.resetAllMocks();
});

describe("loadHiddenIds", () => {
  it("returns empty set when hidden.json does not exist", () => {
    mockExistsSync.mockReturnValue(false);

    const ids = loadHiddenIds();
    expect(ids).toBeInstanceOf(Set);
    expect(ids.size).toBe(0);
  });

  it("returns set of hidden IDs from valid file", () => {
    mockExistsSync.mockReturnValue(true);
    mockReadFileSync.mockReturnValue(JSON.stringify({ hidden: ["id-1", "id-2", "id-3"] }));

    const ids = loadHiddenIds();
    expect(ids.size).toBe(3);
    expect(ids.has("id-1")).toBe(true);
    expect(ids.has("id-2")).toBe(true);
    expect(ids.has("id-3")).toBe(true);
  });

  it("returns empty set when file contains invalid JSON", () => {
    mockExistsSync.mockReturnValue(true);
    mockReadFileSync.mockReturnValue("{{not json");

    const ids = loadHiddenIds();
    expect(ids.size).toBe(0);
  });

  it("returns empty set when hidden field is not an array", () => {
    mockExistsSync.mockReturnValue(true);
    mockReadFileSync.mockReturnValue(JSON.stringify({ hidden: "not-array" }));

    const ids = loadHiddenIds();
    expect(ids.size).toBe(0);
  });
});

describe("addHiddenId", () => {
  it("creates directory if it does not exist", () => {
    mockExistsSync.mockReturnValue(false);

    addHiddenId("test-id");

    expect(mockMkdirSync).toHaveBeenCalledWith(
      expect.stringContaining(".agent-jobs"),
      { recursive: true },
    );
  });

  it("adds ID to existing hidden set and writes atomically", () => {
    // First call to existsSync for loadHiddenIds (hidden.json check)
    // Second call to existsSync for ensureDir (JOBS_DIR check)
    mockExistsSync.mockImplementation((path) => {
      const pathStr = String(path);
      if (pathStr.includes("hidden.json")) return true;
      return true; // dir exists
    });
    mockReadFileSync.mockReturnValue(JSON.stringify({ hidden: ["existing-id"] }));

    addHiddenId("new-id");

    // Should write to a temp file then rename
    expect(mockWriteFileSync).toHaveBeenCalledTimes(1);
    expect(mockRenameSync).toHaveBeenCalledTimes(1);

    // Check the written content includes both IDs
    const writtenContent = mockWriteFileSync.mock.calls[0]![1] as string;
    const parsed = JSON.parse(writtenContent);
    expect(parsed.hidden).toContain("existing-id");
    expect(parsed.hidden).toContain("new-id");
  });

  it("deduplicates IDs (Set behavior)", () => {
    mockExistsSync.mockReturnValue(true);
    mockReadFileSync.mockReturnValue(JSON.stringify({ hidden: ["id-1"] }));

    addHiddenId("id-1"); // Add duplicate

    const writtenContent = mockWriteFileSync.mock.calls[0]![1] as string;
    const parsed = JSON.parse(writtenContent);
    expect(parsed.hidden).toHaveLength(1);
    expect(parsed.hidden).toContain("id-1");
  });
});

describe("removeRegisteredJob", () => {
  it("removes job from jobs.json by ID", () => {
    mockExistsSync.mockReturnValue(true);
    mockReadFileSync.mockReturnValue(JSON.stringify({
      version: "1.0",
      jobs: [
        { id: "j1", name: "server" },
        { id: "j2", name: "worker" },
      ],
    }));

    removeRegisteredJob("j1");

    const writtenContent = mockWriteFileSync.mock.calls[0]![1] as string;
    const parsed = JSON.parse(writtenContent);
    expect(parsed.jobs).toHaveLength(1);
    expect(parsed.jobs[0].id).toBe("j2");
  });

  it("does nothing when jobs.json does not exist", () => {
    mockExistsSync.mockReturnValue(false);

    removeRegisteredJob("j1");

    // Should write empty jobs array
    const writtenContent = mockWriteFileSync.mock.calls[0]![1] as string;
    const parsed = JSON.parse(writtenContent);
    expect(parsed.jobs).toHaveLength(0);
  });
});

describe("setRegisteredJobStatus", () => {
  it("updates job status in jobs.json", () => {
    mockExistsSync.mockReturnValue(true);
    mockReadFileSync.mockReturnValue(JSON.stringify({
      version: "1.0",
      jobs: [
        { id: "j1", name: "server", status: "active" },
      ],
    }));

    setRegisteredJobStatus("j1", "stopped");

    const writtenContent = mockWriteFileSync.mock.calls[0]![1] as string;
    const parsed = JSON.parse(writtenContent);
    expect(parsed.jobs[0].status).toBe("stopped");
  });

  it("does not write when job ID is not found", () => {
    mockExistsSync.mockReturnValue(true);
    mockReadFileSync.mockReturnValue(JSON.stringify({
      version: "1.0",
      jobs: [{ id: "j1", name: "server", status: "active" }],
    }));

    setRegisteredJobStatus("nonexistent", "stopped");

    // Should not write (no matching job found)
    expect(mockWriteFileSync).not.toHaveBeenCalled();
  });
});

describe("killProcess", () => {
  it("returns true on successful kill", () => {
    const originalKill = process.kill;
    process.kill = vi.fn() as typeof process.kill;

    const result = killProcess(12345);
    expect(result).toBe(true);
    expect(process.kill).toHaveBeenCalledWith(12345, "SIGTERM");

    process.kill = originalKill;
  });

  it("returns false when kill throws", () => {
    const originalKill = process.kill;
    process.kill = vi.fn(() => { throw new Error("ESRCH"); }) as typeof process.kill;

    const result = killProcess(99999);
    expect(result).toBe(false);

    process.kill = originalKill;
  });
});
