import {
  AI_CATALOG_TYPE_AGENT,
  AI_CATALOG_TYPE_FLOW,
  AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
  AI_CATALOG_TYPE_FOUNDATIONAL_AGENT,
} from 'ee/ai/catalog/constants';
import { itemTypeValidator, getRegistryItem } from 'ee/ai/catalog/item_type_registry';

describe('item_type_registry', () => {
  it.each`
    type                                  | label
    ${AI_CATALOG_TYPE_AGENT}              | ${'agents'}
    ${AI_CATALOG_TYPE_FLOW}               | ${'flows'}
    ${AI_CATALOG_TYPE_FOUNDATIONAL_AGENT} | ${'foundational agents'}
  `('validates and resolves $label', ({ type }) => {
    expect(itemTypeValidator(type)).toBe(true);
    expect(getRegistryItem(type)).toBeDefined();
  });

  it('rejects third-party flows from the validator', () => {
    expect(itemTypeValidator(AI_CATALOG_TYPE_THIRD_PARTY_FLOW)).toBe(false);
  });

  it('throws for an unknown item type', () => {
    expect(() => getRegistryItem('UNKNOWN')).toThrow('Unknown AI catalog item type: UNKNOWN');
  });

  describe('flow index showActionItem', () => {
    const { showActionItem } = getRegistryItem(AI_CATALOG_TYPE_FLOW).index;

    it.each`
      scenario                                | foundational | isGroupNamespace | expected
      ${'foundational flow at group level'}   | ${true}      | ${true}          | ${false}
      ${'foundational flow at project level'} | ${true}      | ${false}         | ${true}
      ${'custom flow at group level'}         | ${false}     | ${true}          | ${true}
      ${'custom flow at project level'}       | ${false}     | ${false}         | ${true}
    `('returns $expected for $scenario', ({ foundational, isGroupNamespace, expected }) => {
      expect(showActionItem({ foundational }, true, { isGroupNamespace })).toBe(expected);
    });

    it('returns false without consumer admin permission', () => {
      expect(showActionItem({ foundational: false }, false, { isGroupNamespace: false })).toBe(
        false,
      );
    });
  });
});
