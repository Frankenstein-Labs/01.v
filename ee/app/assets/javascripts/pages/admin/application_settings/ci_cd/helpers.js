/**
 * Filters [items] based on a given [searchTerm].
 * Catagories with no items after filtering are not included in the returned object.
 * @param {Object} allItems - { <categoryName>: [{ name, id }] }
 * @param {String} searchTerm
 * @returns {Object}
 */
export function filterItems(allItems, searchTerm) {
  return Object.entries(allItems)
    .map(([key, items]) => ({
      text: key,
      options: items
        .filter((item) => item.name.toLowerCase().includes(searchTerm))
        .map((item) => ({
          text: item.name,
          value: item.key,
        })),
    }))
    .filter((group) => group.options.length > 0);
}
