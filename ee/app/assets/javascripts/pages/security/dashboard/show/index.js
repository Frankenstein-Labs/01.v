import initSecurityDashboard from 'ee/security_dashboard/security_dashboard_init';
import { DASHBOARD_TYPE_INSTANCE } from 'ee/security_dashboard/constants';

initSecurityDashboard(document.getElementById('js-security'), DASHBOARD_TYPE_INSTANCE);
