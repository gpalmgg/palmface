import * as path from 'node:path';
import type { TranscriptData } from './types.js';

export interface StuckInfo {
  file: string;
  count: number;
}

const EDIT_TOOL_NAMES = new Set(['Edit', 'Write', 'NotebookEdit']);
const MIN_STREAK = 3;

/**
 * Detect if the same file has been edited 3+ times in a row with nothing else
 * happening in between. Looks at the tail of the tool history. Returns null
 * when no streak is present.
 */
export function detectStuckStreak(transcript: TranscriptData): StuckInfo | null {
  const tools = transcript.tools;
  if (tools.length < MIN_STREAK) {
    return null;
  }

  // Walk backwards through completed/error tool calls, counting consecutive
  // edits to the same target file.
  let target: string | null = null;
  let count = 0;

  for (let i = tools.length - 1; i >= 0; i -= 1) {
    const tool = tools[i];
    if (tool.status === 'running') {
      continue;
    }
    if (!EDIT_TOOL_NAMES.has(tool.name)) {
      break;
    }
    if (!tool.target) {
      break;
    }
    if (target === null) {
      target = tool.target;
      count = 1;
      continue;
    }
    if (tool.target !== target) {
      break;
    }
    count += 1;
  }

  if (count < MIN_STREAK || target === null) {
    return null;
  }

  return { file: path.basename(target), count };
}
