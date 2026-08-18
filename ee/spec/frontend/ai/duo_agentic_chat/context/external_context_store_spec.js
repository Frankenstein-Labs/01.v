import {
  registerExternalContextProvider,
  getExternalContextItems,
  PERMISSIONS_FORM_CONTEXT_CATEGORY,
} from 'ee/ai/duo_agentic_chat/context/external_context_store';
import { captureExceptionForDuoChat } from 'ee/ai/duo_agentic_chat/observability/sentry_utils';

jest.mock('ee/ai/duo_agentic_chat/observability/sentry_utils');

describe('external context store', () => {
  const disposers = [];
  const register = (...args) => {
    const dispose = registerExternalContextProvider(...args);
    disposers.push(dispose);
    return dispose;
  };

  afterEach(() => {
    disposers.splice(0).forEach((dispose) => dispose());
  });

  it('returns no items when nothing is registered', () => {
    expect(getExternalContextItems()).toEqual([]);
  });

  it('serializes a registered provider into a context item', () => {
    register(PERMISSIONS_FORM_CONTEXT_CATEGORY, () => ({ a: 1 }));

    expect(getExternalContextItems()).toEqual([
      {
        category: PERMISSIONS_FORM_CONTEXT_CATEGORY,
        content: JSON.stringify({ a: 1 }),
        metadata: '{}',
      },
    ]);
  });

  it('reads the provider fresh on each call', () => {
    let value = { v: 'first' };
    register(PERMISSIONS_FORM_CONTEXT_CATEGORY, () => value);

    expect(getExternalContextItems()[0].content).toBe(JSON.stringify({ v: 'first' }));

    value = { v: 'second' };

    expect(getExternalContextItems()[0].content).toBe(JSON.stringify({ v: 'second' }));
  });

  it('omits a provider that returns a nullish value', () => {
    register(PERMISSIONS_FORM_CONTEXT_CATEGORY, () => null);

    expect(getExternalContextItems()).toEqual([]);
  });

  it('skips a provider that throws without breaking the others', () => {
    const error = new Error('boom');
    register(PERMISSIONS_FORM_CONTEXT_CATEGORY, () => {
      throw error;
    });
    register('other_category', () => ({ ok: true }));

    expect(getExternalContextItems()).toEqual([
      { category: 'other_category', content: JSON.stringify({ ok: true }), metadata: '{}' },
    ]);
    expect(captureExceptionForDuoChat).toHaveBeenCalledWith(error);
  });

  it('stops returning a provider after its disposer runs', () => {
    const dispose = register(PERMISSIONS_FORM_CONTEXT_CATEGORY, () => 'content');
    dispose();

    expect(getExternalContextItems()).toEqual([]);
  });

  it('disposing one provider leaves another with the same category intact', () => {
    const disposeStale = register(PERMISSIONS_FORM_CONTEXT_CATEGORY, () => ({ which: 'stale' }));
    register(PERMISSIONS_FORM_CONTEXT_CATEGORY, () => ({ which: 'live' }));

    disposeStale();

    expect(getExternalContextItems()).toEqual([
      {
        category: PERMISSIONS_FORM_CONTEXT_CATEGORY,
        content: JSON.stringify({ which: 'live' }),
        metadata: '{}',
      },
    ]);
  });
});
