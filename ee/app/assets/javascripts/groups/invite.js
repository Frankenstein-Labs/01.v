import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import { s__ } from '~/locale';
import InviteMembers from './components/invite_members.vue';

export default () => {
  const el = document.querySelector('.js-invite-members');

  if (!el) {
    return null;
  }

  const { emails, docsPath } = el.dataset;
  const inviteLabel = s__('InviteMember|Invite Members (optional)');

  return initVueApp({
    el,
    name: 'InviteMembersRoot',
    component: InviteMembers,
    props: {
      emails: JSON.parse(emails),
      docsPath,
      inviteLabel,
    },
  });
};
