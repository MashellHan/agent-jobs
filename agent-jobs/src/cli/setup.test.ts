import { describe, it, expect, vi, beforeEach } from "vitest";
import { setup, teardown } from "./setup.js";

vi.mock("fs", () => ({
  existsSync: vi.fn(),
  readFileSync: vi.fn(),
  writeFileSync: vi.fn(),
  renameSync: vi.fn(),
}));

vi.mock("os", () => ({
  homedir: vi.fn(() => "/mock-home"),
}));

import { existsSync, readFileSync, writeFileSync, renameSync } from "fs";

const mockExistsSync = vi.mocked(existsSync);
const mockReadFileSync = vi.mocked(readFileSync);
const mockWriteFileSync = vi.mocked(writeFileSync);
const mockRenameSync = vi.mocked(renameSync);

beforeEach(() => {
  vi.resetAllMocks();
  vi.spyOn(process.stdout, "write").mockImplementation(() => true);
});

describe("setup", () => {
  it("creates hook when settings file does not exist", () => {
    mockExistsSync.mockReturnValue(false);

    setup();

    expect(mockWriteFileSync).toHaveBeenCalledOnce();
    const written = JSON.parse(mockWriteFileSync.mock.calls[0]![1] as string);
    expect(written.hooks.PostToolUse).toHaveLength(1);
    expect(written.hooks.PostToolUse[0].hooks[0].command).toContain("detect");
    expect(mockRenameSync).toHaveBeenCalledOnce();
  });

  it("skips when hook is already installed", () => {
    mockExistsSync.mockReturnValue(true);
    mockReadFileSync.mockReturnValue(JSON.stringify({
      hooks: {
        PostToolUse: [{
          matcher: "Bash",
          hooks: [{ type: "command", command: "node /path/to/agent-jobs-detect" }],
        }],
      },
    }));

    setup();

    expect(mockWriteFileSync).not.toHaveBeenCalled();
    expect(process.stdout.write).toHaveBeenCalledWith(
      expect.stringContaining("already installed")
    );
  });

  it("adds hook to existing settings without PostToolUse", () => {
    mockExistsSync.mockReturnValue(true);
    mockReadFileSync.mockReturnValue(JSON.stringify({
      hooks: { PreToolUse: [] },
    }));

    setup();

    const written = JSON.parse(mockWriteFileSync.mock.calls[0]![1] as string);
    expect(written.hooks.PostToolUse).toHaveLength(1);
    expect(written.hooks.PreToolUse).toEqual([]);
  });

  it("handles corrupt settings.json gracefully", () => {
    mockExistsSync.mockReturnValue(true);
    mockReadFileSync.mockReturnValue("{invalid json");

    setup();

    expect(mockWriteFileSync).toHaveBeenCalledOnce();
    const written = JSON.parse(mockWriteFileSync.mock.calls[0]![1] as string);
    expect(written.hooks.PostToolUse).toHaveLength(1);
  });
});

describe("teardown", () => {
  it("removes agent-jobs hook", () => {
    mockExistsSync.mockReturnValue(true);
    mockReadFileSync.mockReturnValue(JSON.stringify({
      hooks: {
        PostToolUse: [{
          matcher: "Bash",
          hooks: [{ type: "command", command: "node /path/to/detect.js" }],
        }, {
          matcher: "Bash",
          hooks: [{ type: "command", command: "node agent-jobs detect" }],
        }],
      },
    }));

    teardown();

    const written = JSON.parse(mockWriteFileSync.mock.calls[0]![1] as string);
    expect(written.hooks.PostToolUse).toHaveLength(1);
    expect(written.hooks.PostToolUse[0].hooks[0].command).not.toContain("agent-jobs");
  });

  it("reports nothing to remove when no hooks exist", () => {
    mockExistsSync.mockReturnValue(false);

    teardown();

    expect(mockWriteFileSync).not.toHaveBeenCalled();
    expect(process.stdout.write).toHaveBeenCalledWith(
      expect.stringContaining("No hooks found")
    );
  });

  it("reports nothing to remove when no agent-jobs hook found", () => {
    mockExistsSync.mockReturnValue(true);
    mockReadFileSync.mockReturnValue(JSON.stringify({
      hooks: {
        PostToolUse: [{
          matcher: "Bash",
          hooks: [{ type: "command", command: "some-other-tool" }],
        }],
      },
    }));

    teardown();

    expect(mockWriteFileSync).not.toHaveBeenCalled();
    expect(process.stdout.write).toHaveBeenCalledWith(
      expect.stringContaining("No agent-jobs hook found")
    );
  });
});
