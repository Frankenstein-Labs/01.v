import { generateDescriptionAction } from 'ee/ai/editor_actions/generate_description';
import { mountMarkdownEditor as mountCEMarkdownEditor } from '~/vue_shared/components/markdown/mount_markdown_editor';

export function mountMarkdownEditor(options = {}) {
  const provideEEAiActions = [];
  let mrGeneratedContent;

  if (window.gon?.licensed_features?.generateDescription) {
    provideEEAiActions.push(generateDescriptionAction());
  }

  const editor = mountCEMarkdownEditor({
    provide: {
      legacyEditorAiActions: provideEEAiActions,
      mrGeneratedContent,
      ...(options.provide ?? {}),
    },
  });

  mrGeneratedContent?.setEditor(editor);

  return editor;
}
