import type { RenderContext } from '../../types.js';
import { formatActiveClaudeMd } from '../../active-claude-md.js';
import { label } from '../colors.js';

export function renderEnvironmentLine(ctx: RenderContext): string | null {
  const display = ctx.config?.display;

  if (display?.showConfigCounts === false) {
    return null;
  }

  const totalCounts = ctx.claudeMdCount + ctx.rulesCount + ctx.mcpCount + ctx.hooksCount;
  const threshold = display?.environmentThreshold ?? 0;

  if (totalCounts === 0 || totalCounts < threshold) {
    return null;
  }

  const parts: string[] = [];

  if (ctx.claudeMdCount > 0) {
    const scopeBadge = display?.showActiveClaudeMd && ctx.activeClaudeMd
      ? formatActiveClaudeMd(ctx.activeClaudeMd)
      : null;
    const claudeMdLabel = scopeBadge
      ? `${ctx.claudeMdCount} CLAUDE.md [${scopeBadge}]`
      : `${ctx.claudeMdCount} CLAUDE.md`;
    parts.push(claudeMdLabel);
  }

  if (ctx.rulesCount > 0) {
    parts.push(`${ctx.rulesCount} rules`);
  }

  if (ctx.mcpCount > 0) {
    parts.push(`${ctx.mcpCount} MCPs`);
  }

  if (ctx.hooksCount > 0) {
    parts.push(`${ctx.hooksCount} hooks`);
  }

  if (parts.length === 0) {
    return null;
  }

  return label(parts.join(' | '), ctx.config?.colors);
}
