import { initMarkdownEditor as initMarkdownEditorFOSS } from '~/pages/projects/merge_requests/init_markdown_editor';
import { parseBoolean } from '~/lib/utils/common_utils';

export function initMarkdownEditor() {
  const { projectId, targetBranch, sourceBranch, canSummarize, summarizeDisabledReason } =
    document.querySelector('.js-markdown-editor').dataset;

  return initMarkdownEditorFOSS({
    projectId,
    targetBranch,
    sourceBranch,
    canSummarizeChanges: parseBoolean(canSummarize),
    summarizeDisabledReason,
  });
}
