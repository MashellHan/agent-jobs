import type { Instance } from "ink";

/** Shared reference to the Ink render instance, set by index.tsx at startup. */
let instance: Instance | null = null;

export function setInkInstance(inst: Instance): void {
  instance = inst;
}

export function getInkInstance(): Instance | null {
  return instance;
}
