import { buildFormContext } from 'ee/ai/shared/utils/form_context_utils';

describe('buildFormContext', () => {
  it('wraps formId and formContent in a form_context envelope', () => {
    const formContent = { namespace: ['read_api'], user: ['read_user'] };

    expect(buildFormContext({ formId: 'ask-duo-pat', formContent })).toEqual([
      {
        category: 'form_context',
        content: JSON.stringify({ form_id: 'ask-duo-pat', form_content: formContent }),
        metadata: '{}',
      },
    ]);
  });

  it('defaults formContent to an empty object when omitted', () => {
    expect(buildFormContext({ formId: 'ask-duo-pat' })).toEqual([
      {
        category: 'form_context',
        content: JSON.stringify({ form_id: 'ask-duo-pat', form_content: {} }),
        metadata: '{}',
      },
    ]);
  });
});
