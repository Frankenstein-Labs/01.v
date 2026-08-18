import { runMessageTransformers } from 'ee/ai/duo_agentic_chat/transformers/index';

describe('runMessageTransformers', () => {
  const messages = [{ id: 1 }, { id: 2 }];

  it('returns the original messages when no transformers are provided', () => {
    expect(runMessageTransformers(messages, [])).toEqual(messages);
  });

  it('applies a single transformer', () => {
    const transformer = (msgs) => msgs.map((m) => ({ ...m, transformed: true }));
    const result = runMessageTransformers(messages, [transformer]);
    expect(result).toEqual([
      { id: 1, transformed: true },
      { id: 2, transformed: true },
    ]);
  });

  it('applies transformers in order, feeding each output into the next', () => {
    const order = [];
    const first = (msgs) => {
      order.push('first');
      return msgs.map((m) => ({ ...m, step: 'first' }));
    };
    const second = (msgs) => {
      order.push('second');
      return msgs.map((m) => ({ ...m, step: 'second' }));
    };

    const result = runMessageTransformers(messages, [first, second]);

    expect(order).toEqual(['first', 'second']);
    expect(result.every((m) => m.step === 'second')).toBe(true);
  });

  it('passes the output of each transformer as input to the next', () => {
    const addA = (msgs) => msgs.map((m) => ({ ...m, tags: [...(m.tags ?? []), 'a'] }));
    const addB = (msgs) => msgs.map((m) => ({ ...m, tags: [...(m.tags ?? []), 'b'] }));

    const result = runMessageTransformers([{ id: 1 }], [addA, addB]);
    expect(result[0].tags).toEqual(['a', 'b']);
  });
});
