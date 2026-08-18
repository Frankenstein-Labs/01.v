export default () => ({
  hasLoaded: false,
  isLoading: false,
  rules: [],
  rulesPagination: {
    total: 0,
    nextPage: null,
  },
  fallbackApprovalsRequired: 0,
  minFallbackApprovalsRequired: 0,
  initialRules: [],
  oldRules: [],
  resetToDefault: false,
  drawerOpen: false,
  editRule: null,
});
