import initSecurityDashboard from 'ee/security_dashboard/security_dashboard_init';
import { DASHBOARD_TYPE_PROJECT } from 'ee/security_dashboard/constants';

initSecurityDashboard(
  document.getElementById('js-project-security-dashboard'),
  DASHBOARD_TYPE_PROJECT,
);
