/**
 * Checks if a group or project has a specific dashboard by slug
 * @param {Object} groupOrProject - The group or project object
 * @param {string} dashboardName - The slug of the dashboard to find
 * @returns {Object|undefined} The dashboard object if found, undefined otherwise
 */
export const hasDashboard = (groupOrProject, dashboardName) => {
  return Boolean(
    groupOrProject.customizableDashboards?.nodes?.find(
      (dashboard) => dashboard.slug === dashboardName,
    ),
  );
};
