import { GlLink, GlSprintf } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import BotCommentAction from 'ee/security_orchestration/components/policy_editor/scan_result/action/bot_message_action.vue';
import { DISABLED_BOT_MESSAGE_ACTION } from 'ee/security_orchestration/components/policy_editor/scan_result/lib';

describe('BotCommentAction', () => {
  let wrapper;

  const factory = () => {
    wrapper = shallowMount(BotCommentAction, { stubs: { GlSprintf } });
  };

  const findHelpLink = () => wrapper.findComponent(GlLink);
  const findSectionLayout = () => wrapper.findComponent(SectionLayout);

  it('renders the correct content text', () => {
    factory();
    expect(findSectionLayout().exists()).toBe(true);
    expect(findSectionLayout().text()).toContain(
      'Send a bot message as comment to merge request creator.',
    );
  });

  it('renders the example link', () => {
    factory();
    expect(findHelpLink().exists()).toBe(true);
    expect(findHelpLink().text()).toBe('What does an example message look like?');
    expect(findHelpLink().attributes('href')).toBe(
      '/help/user/application_security/policies/merge_request_approval_policies#example-bot-messages',
    );
  });

  it('emits changed event when action is removed', () => {
    factory();
    findSectionLayout().vm.$emit('remove');

    expect(wrapper.emitted('changed')).toEqual([[DISABLED_BOT_MESSAGE_ACTION]]);
  });
});
