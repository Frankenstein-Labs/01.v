import { groupCatalogItems } from 'ee/policy_store/components/editor/utils';
import {
  CATEGORY_ADVANCED,
  CATEGORY_DEPLOYMENT,
  CATEGORY_ENFORCEMENT,
} from 'ee/policy_store/catalog/categories';

describe('groupCatalogItems', () => {
  const item = (id, category, description = `about ${id}`) => ({
    id,
    label: `Label ${id}`,
    description,
    category,
  });

  it('groups items by category, in the declared order with translated labels', () => {
    const groups = groupCatalogItems([
      item('a', CATEGORY_DEPLOYMENT),
      item('b', CATEGORY_ENFORCEMENT),
      item('c', CATEGORY_ADVANCED),
      item('d', CATEGORY_DEPLOYMENT),
    ]);

    expect(groups.map(({ label }) => label)).toEqual(['Enforcement', 'Advanced', 'Deployment']);
    expect(groups[2].items.map(({ id }) => id)).toEqual(['a', 'd']);
  });

  it('returns everything when the query is empty or whitespace', () => {
    const catalog = [item('a', CATEGORY_ADVANCED)];

    expect(groupCatalogItems(catalog)).toHaveLength(1);
    expect(groupCatalogItems(catalog, '   ')).toHaveLength(1);
  });

  it('filters by label and description, case-insensitively', () => {
    const catalog = [
      item('a', CATEGORY_ADVANCED, 'checks the freeze window'),
      item('b', CATEGORY_ADVANCED, 'something else'),
    ];

    expect(groupCatalogItems(catalog, 'FREEZE')[0].items.map(({ id }) => id)).toEqual(['a']);
    expect(groupCatalogItems(catalog, 'label b')[0].items.map(({ id }) => id)).toEqual(['b']);
    expect(groupCatalogItems(catalog, 'no match')).toEqual([]);
  });

  it('puts uncategorised items first, under a Custom heading', () => {
    const groups = groupCatalogItems([
      item('a', CATEGORY_ADVANCED),
      { id: 'b', label: 'Label b', description: 'about b' },
    ]);

    expect(groups.map(({ label }) => label)).toEqual(['Custom', 'Advanced']);
  });

  it('keeps a category the order does not know visible, sorted last with its id as label', () => {
    const groups = groupCatalogItems([
      { ...item('z', 'zzz-unknown') },
      item('a', CATEGORY_DEPLOYMENT),
      { ...item('m', 'aaa-unknown') },
    ]);

    expect(groups.map(({ label }) => label)).toEqual(['Deployment', 'aaa-unknown', 'zzz-unknown']);
  });
});
