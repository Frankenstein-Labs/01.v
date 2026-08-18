import '~/pages/groups/group_members';
import initConfirmModal from '~/confirm_modal';
import { initMinimalAccessProvisioningAlert } from 'ee/block_seat_overages';

const LDAP_SYNC_NOW_BUTTON_SELECTOR = '.js-ldap-sync-now-button';
if (document.querySelector(LDAP_SYNC_NOW_BUTTON_SELECTOR)) {
  initConfirmModal({ selector: LDAP_SYNC_NOW_BUTTON_SELECTOR });
}

initMinimalAccessProvisioningAlert();
