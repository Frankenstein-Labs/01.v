import { initSimpleApp } from '~/helpers/init_simple_app_helper';
import initInviteMembersModal from '~/invite_members/init_invite_members_modal';
import GetStarted from '../components/get_started.vue';

initInviteMembersModal();
initSimpleApp('#js-get-started-app', GetStarted);
