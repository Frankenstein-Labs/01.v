// Vue 2 / 3 test helper to extract text from a Vue slot's content
export const getSlotText = (slotContent) => {
  const node = slotContent[0];
  // Vue 3: text is nested in children
  if (node.children && Array.isArray(node.children)) {
    return node.children[0]?.text || '';
  }
  // Vue 2: text is directly on the node
  return node.text || '';
};
