export default ({ enabled = false, totalItems = 0 }) => ({
  enabled,
  pagination: {
    totalItems,
  },
});
