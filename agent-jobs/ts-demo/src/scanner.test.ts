import { describe, it, expect } from "vitest";
import { friendlyLiveName } from "./scanner.js";

describe("friendlyLiveName", () => {
  it("extracts script filename with port", () => {
    expect(friendlyLiveName("node", "node /Users/dev/api/server.js", 4000)).toBe("server.js :4000");
  });

  it("extracts script filename without port", () => {
    expect(friendlyLiveName("node", "node /Users/dev/api/server.js", 0)).toBe("server.js");
  });

  it("detects next framework with port", () => {
    expect(friendlyLiveName("node", "node /usr/local/bin/next start", 3000)).toBe("next :3000");
  });

  it("detects vite framework with port", () => {
    expect(friendlyLiveName("node", "node node_modules/.bin/vite --port 5173", 5173)).toBe("vite :5173");
  });

  it("detects uvicorn framework", () => {
    expect(friendlyLiveName("python3", "python3 -m uvicorn main:app", 8000)).toBe("uvicorn :8000");
  });

  it("detects gunicorn framework", () => {
    expect(friendlyLiveName("python3", "gunicorn app:application -w 4", 8000)).toBe("gunicorn :8000");
  });

  it("detects flask framework", () => {
    expect(friendlyLiveName("python3", "python3 -m flask run", 5000)).toBe("flask :5000");
  });

  it("falls back to command + port when no script or framework", () => {
    expect(friendlyLiveName("ruby", "ruby -e 'some code'", 9292)).toBe("ruby :9292");
  });

  it("falls back to command only when no port", () => {
    expect(friendlyLiveName("ruby", "ruby -e 'some code'", 0)).toBe("ruby");
  });

  it("prefers script over framework detection", () => {
    // If script arg is found, it wins over framework name
    expect(friendlyLiveName("node", "node app.ts", 3000)).toBe("app.ts :3000");
  });

  it("handles .py scripts", () => {
    expect(friendlyLiveName("python3", "python3 app.py", 8080)).toBe("app.py :8080");
  });

  it("handles nuxt framework", () => {
    expect(friendlyLiveName("node", "node .output/server/index.mjs nuxt", 3000)).toBe("index.mjs :3000");
  });
});
