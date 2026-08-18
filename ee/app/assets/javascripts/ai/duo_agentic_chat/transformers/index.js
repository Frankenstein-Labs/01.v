export const runMessageTransformers = (messages, transformers) =>
  transformers.reduce((msgs, transformer) => transformer(msgs), messages);
