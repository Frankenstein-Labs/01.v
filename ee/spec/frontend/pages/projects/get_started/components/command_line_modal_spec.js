import { GlModal, GlTabs, GlLink } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import CommandLineModal from 'ee/pages/projects/get_started/components/command_line_modal.vue';
import { copyToClipboard } from '~/lib/utils/copy_to_clipboard';

jest.mock('~/lib/utils/copy_to_clipboard');

describe('CommandLineModal', () => {
  let wrapper;

  const defaultProvide = {
    projectName: 'test-project',
    projectPath: 'test-project',
    sshUrl: 'git@gitlab.com:test/test-project.git',
    httpUrl: 'https://gitlab.com/test/test-project.git',
    sshKeyPath: '/profile/keys',
  };

  const defaultProps = {
    defaultBranch: 'main',
    modalId: 'command-line-modal',
  };

  const createComponent = (props = {}, provide = {}, additionalStubs = {}) => {
    const defaultStubs = { GlLink };

    wrapper = shallowMountExtended(CommandLineModal, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        ...defaultProvide,
        ...provide,
      },
      stubs: {
        ...defaultStubs,
        ...additionalStubs,
      },
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findTabs = () => wrapper.findComponent(GlTabs);
  const findHttpsTab = () => wrapper.findByTestId('https-tab');
  const findSshTab = () => wrapper.findByTestId('ssh-tab');
  const findLearnGitLink = () => wrapper.findComponentByTestId('learn-git-link');
  const findSshKeyLink = () => wrapper.findComponentByTestId('ssh-key-link');
  const findLearnSshLink = () => wrapper.findComponentByTestId('learn-ssh-link');
  const findHttpsRepoUrl = () => wrapper.findByTestId('https-repo-url');
  const findHttpsCloneAddCommand = () => wrapper.findByTestId('https-clone-add-command');
  const findHttpsPushExistingCommand = () => wrapper.findByTestId('https-push-existing-command');
  const findSshRepoUrl = () => wrapper.findByTestId('ssh-repo-url');
  const findSshCloneAddCommand = () => wrapper.findByTestId('ssh-clone-add-command');
  const findSshPushExistingCommand = () => wrapper.findByTestId('ssh-push-existing-command');
  const findHttpsRepoUrlCopyBtn = () => wrapper.findComponentByTestId('https-repo-url-copy-btn');
  const findHttpsCloneAddCopyBtn = () => wrapper.findComponentByTestId('https-clone-add-copy-btn');
  const findHttpsPushExistingCopyBtn = () =>
    wrapper.findComponentByTestId('https-push-existing-copy-btn');
  const findSshRepoUrlCopyBtn = () => wrapper.findComponentByTestId('ssh-repo-url-copy-btn');
  const findSshCloneAddCopyBtn = () => wrapper.findComponentByTestId('ssh-clone-add-copy-btn');
  const findSshPushExistingCopyBtn = () =>
    wrapper.findComponentByTestId('ssh-push-existing-copy-btn');

  describe('rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the modal with correct props', () => {
      expect(findModal().exists()).toBe(true);
      expect(findModal().props('modalId')).toBe('command-line-modal');
      expect(findModal().props('title')).toBe('Command-line instructions');
    });

    it('renders tabs component', () => {
      expect(findTabs().exists()).toBe(true);
    });

    it('renders HTTPS and SSH tabs', () => {
      expect(findHttpsTab().attributes('title')).toBe('HTTPS');
      expect(findSshTab().attributes('title')).toBe('SSH');
    });

    it('renders learn git link', () => {
      expect(findLearnGitLink().exists()).toBe(true);
      expect(findLearnGitLink().text()).toBe('Get started with Git');
      expect(findLearnGitLink().props('href')).toContain('/topics/git/get_started.md');
      expect(findLearnGitLink().props('target')).toBe('_blank');
    });
  });

  describe('HTTPS tab content', () => {
    beforeEach(() => {
      createComponent();
    });

    it('displays HTTPS repository URL', () => {
      expect(findHttpsRepoUrl().text()).toBe(defaultProvide.httpUrl);
      expect(findHttpsRepoUrlCopyBtn().props('text')).toBe(defaultProvide.httpUrl);
    });

    it('displays clone and add command with HTTPS URL', () => {
      const expectedCommand = `git clone ${defaultProvide.httpUrl}
cd ${defaultProvide.projectPath}
touch README.md
git add README.md
git commit -m "Add README"
git push -u origin ${defaultProps.defaultBranch}`;

      expect(findHttpsCloneAddCommand().text()).toBe(expectedCommand);
      expect(findHttpsCloneAddCopyBtn().props('text')).toBe(expectedCommand);
    });

    it('displays push existing repository command with HTTPS URL', () => {
      const expectedCommand = `git remote add origin ${defaultProvide.httpUrl}
git branch -M ${defaultProps.defaultBranch}
git push -u origin ${defaultProps.defaultBranch}`;

      expect(findHttpsPushExistingCommand().text()).toBe(expectedCommand);
      expect(findHttpsPushExistingCopyBtn().props('text')).toBe(expectedCommand);
    });
  });

  describe('SSH tab content', () => {
    beforeEach(async () => {
      createComponent();
      findTabs().vm.$emit('input', 1);
      await nextTick();
    });

    it('displays SSH links', () => {
      expect(findSshKeyLink().exists()).toBe(true);
      expect(findSshKeyLink().text()).toBe('Add an SSH key to your GitLab account');
      expect(findSshKeyLink().props('href')).toBe(defaultProvide.sshKeyPath);
      expect(findSshKeyLink().props('target')).toBe('_blank');

      expect(findLearnSshLink().exists()).toBe(true);
      expect(findLearnSshLink().text()).toBe('Use SSH keys to communicate with GitLab');
      expect(findLearnSshLink().props('href')).toContain('/user/ssh.md');
      expect(findLearnSshLink().props('target')).toBe('_blank');
    });

    it('displays SSH repository URL', () => {
      expect(findSshRepoUrl().text()).toBe(defaultProvide.sshUrl);
      expect(findSshRepoUrlCopyBtn().props('text')).toBe(defaultProvide.sshUrl);
    });

    it('displays clone and add command with SSH URL', () => {
      const expectedCommand = `git clone ${defaultProvide.sshUrl}
cd ${defaultProvide.projectPath}
touch README.md
git add README.md
git commit -m "Add README"
git push -u origin ${defaultProps.defaultBranch}`;

      expect(findSshCloneAddCommand().text()).toBe(expectedCommand);
      expect(findSshCloneAddCopyBtn().props('text')).toBe(expectedCommand);
    });

    it('displays push existing repository command with SSH URL', () => {
      const expectedCommand = `git remote add origin ${defaultProvide.sshUrl}
git branch -M ${defaultProps.defaultBranch}
git push -u origin ${defaultProps.defaultBranch}`;

      expect(findSshPushExistingCommand().text()).toBe(expectedCommand);
      expect(findSshPushExistingCopyBtn().props('text')).toBe(expectedCommand);
    });
  });

  describe('tab switching', () => {
    const { bindInternalEventDocument } = useMockInternalEventsTracking();

    beforeEach(() => {
      createComponent();
    });

    it('tracks tab change events', () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      findTabs().vm.$emit('input', 1);

      expect(trackEventSpy).toHaveBeenCalledWith(
        'click_tab_in_command_line_instructions_modal',
        {
          label: 'ssh',
        },
        undefined,
      );
    });

    it('tracks HTTPS tab selection', () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      findTabs().vm.$emit('input', 0);

      expect(trackEventSpy).toHaveBeenCalledWith(
        'click_tab_in_command_line_instructions_modal',
        {
          label: 'https',
        },
        undefined,
      );
    });
  });

  describe('link click tracking', () => {
    const { bindInternalEventDocument } = useMockInternalEventsTracking();

    beforeEach(() => {
      createComponent();
    });

    it('tracks learn git link clicks', async () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      await findLearnGitLink().trigger('click');

      expect(trackEventSpy).toHaveBeenCalledWith(
        'click_learn_git_in_command_line_instructions_modal',
        {},
        undefined,
      );
    });

    it('tracks SSH key link clicks', async () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      await findSshKeyLink().trigger('click');

      expect(trackEventSpy).toHaveBeenCalledWith(
        'click_ssh_key_setup_in_command_line_instructions_modal',
        {},
        undefined,
      );
    });

    it('tracks learn SSH link clicks', async () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      await findLearnSshLink().trigger('click');

      expect(trackEventSpy).toHaveBeenCalledWith(
        'click_learn_ssh_in_command_line_instructions_modal',
        {},
        undefined,
      );
    });
  });

  describe('copy functionality', () => {
    const { bindInternalEventDocument } = useMockInternalEventsTracking();
    let trackEventSpy;

    const clipboardButtonStub = {
      ClipboardButton: {
        template: '<button @click="$emit(\'click\')" v-bind="$attrs"><slot /></button>',
        inheritAttrs: false,
      },
    };

    beforeEach(() => {
      createComponent({}, {}, clipboardButtonStub);
      const tracking = bindInternalEventDocument(wrapper.element);
      trackEventSpy = tracking.trackEventSpy;
    });

    afterEach(() => {
      jest.restoreAllMocks();
    });

    it('tracks copy events when HTTPS repo URL copy button is clicked', async () => {
      await findHttpsRepoUrlCopyBtn().trigger('click');

      expect(copyToClipboard).toHaveBeenCalledWith(defaultProvide.httpUrl);
      expect(trackEventSpy).toHaveBeenCalledWith(
        'copy_command_in_command_line_instructions_modal',
        {
          label: 'https_repo_url',
        },
        undefined,
      );
    });

    it('tracks copy events when HTTPS clone and add copy button is clicked', async () => {
      await findHttpsCloneAddCopyBtn().trigger('click');

      expect(copyToClipboard).toHaveBeenCalled();
      expect(trackEventSpy).toHaveBeenCalledWith(
        'copy_command_in_command_line_instructions_modal',
        {
          label: 'https_clone_and_add',
        },
        undefined,
      );
    });

    it('tracks copy events when HTTPS push existing copy button is clicked', async () => {
      await findHttpsPushExistingCopyBtn().trigger('click');

      expect(copyToClipboard).toHaveBeenCalled();
      expect(trackEventSpy).toHaveBeenCalledWith(
        'copy_command_in_command_line_instructions_modal',
        {
          label: 'https_push_existing',
        },
        undefined,
      );
    });

    it('tracks copy events when SSH repo URL copy button is clicked', async () => {
      // Switch to SSH tab first
      findTabs().vm.$emit('input', 1);
      await nextTick();

      await findSshRepoUrlCopyBtn().trigger('click');

      expect(copyToClipboard).toHaveBeenCalledWith(defaultProvide.sshUrl);
      expect(trackEventSpy).toHaveBeenCalledWith(
        'copy_command_in_command_line_instructions_modal',
        {
          label: 'ssh_repo_url',
        },
        undefined,
      );
    });

    it('tracks copy events when SSH clone and add copy button is clicked', async () => {
      findTabs().vm.$emit('input', 1);
      await nextTick();

      await findSshCloneAddCopyBtn().trigger('click');

      expect(copyToClipboard).toHaveBeenCalled();
      expect(trackEventSpy).toHaveBeenCalledWith(
        'copy_command_in_command_line_instructions_modal',
        {
          label: 'ssh_clone_and_add',
        },
        undefined,
      );
    });

    it('tracks copy events when SSH push existing copy button is clicked', async () => {
      findTabs().vm.$emit('input', 1);
      await nextTick();

      await findSshPushExistingCopyBtn().trigger('click');

      expect(copyToClipboard).toHaveBeenCalled();
      expect(trackEventSpy).toHaveBeenCalledWith(
        'copy_command_in_command_line_instructions_modal',
        {
          label: 'ssh_push_existing',
        },
        undefined,
      );
    });
  });
});
