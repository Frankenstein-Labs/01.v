import { s__ } from '~/locale';
import { searchInItemsProperties } from '~/lib/utils/search_utils';
import { CATEGORY_LABELS, CATEGORY_ORDER } from '../../catalog/categories';

/**
 * Filters a catalog by search query and groups it for the drawer.
 *
 * Groups follow CATEGORY_ORDER; categories the order does not know sort alphabetically
 * after the known ones and fall back to their raw id as the label, so an unmapped
 * category stays visible rather than disappearing. Uncategorised entries come first,
 * under a Custom heading.
 *
 * @param {Array} catalog trigger/rule/action definitions
 * @param {String} searchQuery matched against each entry's label and description
 * @returns {Array<{ label: String, items: Array }>}
 */
export const groupCatalogItems = (catalog, searchQuery = '') => {
  const filtered = searchInItemsProperties({
    items: catalog,
    properties: ['label', 'description'],
    searchQuery: searchQuery.trim(),
  });

  const groups = {};
  const uncategorised = [];

  filtered.forEach((item) => {
    if (!item.category) {
      uncategorised.push(item);
      return;
    }

    groups[item.category] = groups[item.category] || [];
    groups[item.category].push(item);
  });

  const sorted = Object.entries(groups).sort(([a], [b]) => {
    const ai = CATEGORY_ORDER.indexOf(a);
    const bi = CATEGORY_ORDER.indexOf(b);

    if (ai === -1 && bi === -1) return a.localeCompare(b);
    if (ai === -1) return 1;
    if (bi === -1) return -1;

    return ai - bi;
  });

  return [
    ...(uncategorised.length ? [{ label: s__('PolicyStore|Custom'), items: uncategorised }] : []),
    ...sorted.map(([category, items]) => ({
      label: CATEGORY_LABELS[category] || category,
      items,
    })),
  ];
};
