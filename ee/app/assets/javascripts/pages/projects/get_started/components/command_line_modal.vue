<script>
import { GlModal, GlTabs, GlTab, GlLink } from '@gitlab/ui';
import { InternalEvents } from '~/tracking';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';
import { copyToClipboard } from '~/lib/utils/copy_to_clipboard';
import { helpPagePath } from '~/helpers/help_page_helper';
import { __ } from '~/locale';

const trackingMixin = InternalEvents.mixin();
const TABS = {
  HTTPS: 0,
  SSH: 1,
};
const PROTOCOLS = {
  [TABS.HTTPS]: 'https',
  [TABS.SSH]: 'ssh',
};

export default {
  name: 'CommandLineModal',
  components: {
    GlModal,
    GlTabs,
    GlTab,
    GlLink,
    ClipboardButton,
  },
  mixins: [trackingMixin],
  inject: ['projectName', 'projectPath', 'sshUrl', 'httpUrl', 'sshKeyPath'],
  props: {
    defaultBranch: {
      type: String,
      required: true,
    },
    modalId: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      activeTab: TABS.HTTPS,
    };
  },
  computed: {
    currentProtocol() {
      return PROTOCOLS[this.activeTab];
    },
    currentCloneUrl() {
      return this.activeTab === TABS.SSH ? this.sshUrl : this.httpUrl;
    },
    /* eslint-disable @gitlab/require-i18n-strings */
    cloneAndAddCommand() {
      const commands = [
        `git clone ${this.currentCloneUrl}`,
        `cd ${this.projectPath}`,
        `touch README.md`,
        `git add README.md`,
        `git commit -m "Add README"`,
        `git push -u origin ${this.defaultBranch}`,
      ];
      return commands.join('\n');
    },

    pushExistingRepoCommand() {
      const commands = [
        `git remote add origin ${this.currentCloneUrl}`,
        `git branch -M ${this.defaultBranch}`,
        `git push -u origin ${this.defaultBranch}`,
      ];
      return commands.join('\n');
    },
    /* eslint-enable @gitlab/require-i18n-strings */
    commandSections() {
      return [
        {
          title: __('Repository URL'),
          content: this.currentCloneUrl,
          testId: `${this.currentProtocol}-repo-url`,
          copyBtnTestId: `${this.currentProtocol}-repo-url-copy-btn`,
          onCopy: () => this.handleCopy(this.currentCloneUrl, `${this.currentProtocol}_repo_url`),
        },
        {
          title: __('Clone and add files'),
          content: this.cloneAndAddCommand,
          testId: `${this.currentProtocol}-clone-add-command`,
          copyBtnTestId: `${this.currentProtocol}-clone-add-copy-btn`,
          onCopy: () =>
            this.handleCopy(this.cloneAndAddCommand, `${this.currentProtocol}_clone_and_add`),
          extraClass: 'gl-leading-20',
        },
        {
          title: __('Push an existing repository'),
          content: this.pushExistingRepoCommand,
          testId: `${this.currentProtocol}-push-existing-command`,
          copyBtnTestId: `${this.currentProtocol}-push-existing-copy-btn`,
          onCopy: () =>
            this.handleCopy(this.pushExistingRepoCommand, `${this.currentProtocol}_push_existing`),
        },
      ];
    },
  },
  methods: {
    handleCopy(text, trackingLabel) {
      copyToClipboard(text);
      this.trackEvent('copy_command_in_command_line_instructions_modal', {
        label: trackingLabel,
      });
    },
    onTabChange(tabIndex) {
      this.trackEvent('click_tab_in_command_line_instructions_modal', {
        label: PROTOCOLS[tabIndex],
      });
    },
    onLearnGitClick() {
      this.trackEvent('click_learn_git_in_command_line_instructions_modal');
    },
    onSshKeyClick() {
      this.trackEvent('click_ssh_key_setup_in_command_line_instructions_modal');
    },
    onLearnSshClick() {
      this.trackEvent('click_learn_ssh_in_command_line_instructions_modal');
    },
  },
  cancelAction: {
    text: __('Close'),
  },
  gitHelpPagePath: helpPagePath('/topics/git/get_started.md'),
  sshHelpPagePath: helpPagePath('/user/ssh.md'),
  TABS,
};
</script>

<template>
  <gl-modal
    :modal-id="modalId"
    :title="__('Command-line instructions')"
    :action-cancel="$options.cancelAction"
  >
    <div class="gl-mb-4">
      <gl-link
        :href="$options.gitHelpPagePath"
        target="_blank"
        class="gl-mb-3 gl-flex gl-items-center gl-gap-2"
        data-testid="learn-git-link"
        @click="onLearnGitClick"
      >
        {{ __('Get started with Git') }}
      </gl-link>
    </div>

    <gl-tabs v-model="activeTab" @input="onTabChange">
      <gl-tab :title="__('HTTPS')" data-testid="https-tab">
        <div class="gl-mt-4">
          <div
            v-for="(section, index) in commandSections"
            :key="section.testId"
            :class="index === commandSections.length - 1 ? 'gl-mb-0' : 'gl-mb-6'"
          >
            <h4 class="gl-font-weight-semibold gl-mb-3 gl-text-base">
              {{ section.title }}
            </h4>
            <div class="gl-relative">
              <pre
                :class="[
                  'gl-border gl-overflow-auto gl-rounded-base gl-bg-gray-10 gl-p-5',
                  section.extraClass,
                ]"
                :data-testid="section.testId"
                >{{ section.content }}</pre>
              <clipboard-button
                :text="section.content"
                :title="__('Copy')"
                size="small"
                class="gl-absolute gl-right-4 gl-top-4"
                :data-testid="section.copyBtnTestId"
                @click="section.onCopy"
              />
            </div>
          </div>
        </div>
      </gl-tab>

      <gl-tab :title="__('SSH')" data-testid="ssh-tab">
        <div class="gl-mt-4">
          <div class="gl-mb-6 gl-flex gl-flex-col gl-gap-5">
            <gl-link
              :href="sshKeyPath"
              target="_blank"
              class="gl-flex gl-items-center gl-gap-2"
              data-testid="ssh-key-link"
              @click="onSshKeyClick"
            >
              {{ __('Add an SSH key to your GitLab account') }}
            </gl-link>
            <gl-link
              :href="$options.sshHelpPagePath"
              target="_blank"
              class="gl-flex gl-items-center gl-gap-2"
              data-testid="learn-ssh-link"
              @click="onLearnSshClick"
            >
              {{ __('Use SSH keys to communicate with GitLab') }}
            </gl-link>
          </div>

          <div
            v-for="(section, index) in commandSections"
            :key="section.testId"
            :class="index === commandSections.length - 1 ? 'gl-mb-0' : 'gl-mb-6'"
          >
            <h4 class="gl-font-weight-semibold gl-mb-3 gl-text-base">
              {{ section.title }}
            </h4>
            <div class="gl-relative">
              <pre
                :class="[
                  'gl-border gl-overflow-auto gl-rounded-base gl-bg-gray-10 gl-p-5',
                  section.extraClass,
                ]"
                :data-testid="section.testId"
                >{{ section.content }}</pre>
              <clipboard-button
                :text="section.content"
                :title="__('Copy')"
                size="small"
                class="gl-absolute gl-right-4 gl-top-4"
                :data-testid="section.copyBtnTestId"
                @click="section.onCopy"
              />
            </div>
          </div>
        </div>
      </gl-tab>
    </gl-tabs>
  </gl-modal>
</template>
