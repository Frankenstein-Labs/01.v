/**
 * Build a `form_context` additional_context envelope for an agentic chat request.
 *
 * Consumers pass only the form identity and contents. This keeps the envelope
 * shape (category, JSON-encoded content, metadata) out of form components so they
 * don't carry chat tooling logic.
 *
 * @param {Object} params
 * @param {string} params.formId - Identifies the form so the agent only edits this form.
 * @param {Object} [params.formContent] - Current form state, treated as ground truth by the agent.
 * @returns {Array} A single-element additional_context array.
 */
export const buildFormContext = ({ formId, formContent = {} }) => [
  {
    category: 'form_context',
    content: JSON.stringify({
      form_id: formId,
      form_content: formContent,
    }),
    metadata: '{}',
  },
];
