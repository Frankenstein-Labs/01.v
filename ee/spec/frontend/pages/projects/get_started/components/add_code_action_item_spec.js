import { GlIcon, GlLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AddCodeActionItem from 'ee/pages/projects/get_started/components/add_code_action_item.vue';
import CommandLineModal from 'ee/pages/projects/get_started/components/command_line_modal.vue';
import UploadBlobModal from '~/repository/components/upload_blob_modal.vue';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import { createMockDirective } from 'helpers/vue_mock_directive';
import { mockTracking } from 'helpers/tracking_helper';

describe('AddCodeActionItem', () => {
  let wrapper;

  const defaultProvide = {
    projectName: 'test-project',
    defaultBranch: 'main',
    canPushCode: true,
    canPushToBranch: true,
    uploadPath: '/test/upload',
  };

  const createComponent = (actionProps = {}, provide = {}) => {
    wrapper = shallowMountExtended(AddCodeActionItem, {
      propsData: {
        action: {
          title: 'Add Code',
          url: '/web_ide',
          trackLabel: 'add_code',
          ...actionProps,
        },
      },
      provide: {
        ...defaultProvide,
        ...provide,
      },
      directives: { GlModal: createMockDirective('gl-modal') },
    });
  };

  const findActionTitle = () => wrapper.find('span');
  const findCommandLineButton = () => wrapper.findComponentByTestId('command-line-button');
  const findUploadFilesButton = () => wrapper.findComponentByTestId('upload-files-button');
  const findWebIdeLink = () => wrapper.findComponent(GlLink);
  const findCommandLineModal = () => wrapper.findComponent(CommandLineModal);
  const findUploadBlobModal = () => wrapper.findComponent(UploadBlobModal);
  const findActionsList = () => wrapper.find('ul');

  describe('rendering', () => {
    it('renders the action title', () => {
      createComponent();

      expect(findActionTitle().text()).toBe('Add Code');
    });

    it('renders the action list', () => {
      createComponent();

      expect(findActionsList().exists()).toBe(true);
    });
  });

  describe('action buttons and links', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders command line instructions button', () => {
      expect(findCommandLineButton().exists()).toBe(true);
      expect(findCommandLineButton().text()).toBe('Use the command line');
      expect(findCommandLineButton().props('variant')).toBe('link');
    });

    it('renders upload files button when user can push code', () => {
      expect(findUploadFilesButton().exists()).toBe(true);
      expect(findUploadFilesButton().text()).toBe('Upload files');
      expect(findUploadFilesButton().props('variant')).toBe('link');
    });

    it('does not render upload files button when user cannot push code', () => {
      createComponent({}, { canPushCode: false });

      expect(findUploadFilesButton().exists()).toBe(false);
      expect(findCommandLineButton().text()).toBe('Use the command line');
    });

    it('does not render upload files button when user cannot push to branch', () => {
      createComponent({}, { canPushToBranch: false });

      expect(findUploadFilesButton().exists()).toBe(false);
      expect(findCommandLineButton().text()).toBe('Use the command line');
    });

    it('renders WebIDE link', () => {
      expect(findWebIdeLink().exists()).toBe(true);
      expect(findWebIdeLink().text()).toContain('Open the WebIDE');
      expect(findWebIdeLink().attributes('href')).toBe('/web_ide');
      expect(findWebIdeLink().attributes('target')).toBe('_blank');
    });

    it('renders external link icon in WebIDE link', () => {
      const externalIcon = findWebIdeLink().findComponent(GlIcon);

      expect(externalIcon.exists()).toBe(true);
      expect(externalIcon.props('name')).toBe('external-link');
    });

    it('does not render WebIDE link when user cannot push code', () => {
      createComponent({}, { canPushCode: false });

      expect(findWebIdeLink().exists()).toBe(false);
    });

    it('does not render WebIDE link when user cannot push to branch', () => {
      createComponent({}, { canPushToBranch: false });

      expect(findWebIdeLink().exists()).toBe(false);
    });
  });

  describe('modals', () => {
    beforeEach(() => {
      createComponent({});
    });

    it('renders command line modal with correct props', () => {
      expect(findCommandLineModal().exists()).toBe(true);
      expect(findCommandLineModal().props('defaultBranch')).toBe('main');
      expect(findCommandLineModal().props('modalId')).toMatch(/command-line-modal/);
    });

    it('renders upload blob modal when user can push code', () => {
      expect(findUploadBlobModal().props()).toMatchObject({
        commitMessage: 'Upload New File',
        targetBranch: 'main',
        originalBranch: 'main',
        canPushCode: true,
        canPushToBranch: true,
        path: '/test/upload',
        uploadPath: '/test/upload',
      });
    });

    it('does not render upload blob modal when user cannot push code', () => {
      createComponent({}, { canPushCode: false });

      expect(findUploadBlobModal().exists()).toBe(false);
    });

    it('does not render upload blob modal when user cannot push to branch', () => {
      createComponent({}, { canPushToBranch: false });

      expect(findUploadBlobModal().exists()).toBe(false);
    });
  });

  describe('with tracking', () => {
    const { bindInternalEventDocument } = useMockInternalEventsTracking();

    beforeEach(() => {
      createComponent({});
    });

    it('should call trackEvent method when command line button is clicked', async () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      await findCommandLineButton().vm.$emit('click');

      expect(trackEventSpy).toHaveBeenCalledWith(
        'click_command_line_instructions_in_get_started',
        {},
        undefined,
      );
    });

    it('should call trackEvent method when upload files button is clicked', async () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      await findUploadFilesButton().vm.$emit('click');

      expect(trackEventSpy).toHaveBeenCalledWith(
        'click_upload_files_in_get_started',
        {},
        undefined,
      );
    });

    it('should call track method when WebIDE link is clicked', async () => {
      const trackingSpy = mockTracking('_category_', undefined, jest.spyOn);

      await findWebIdeLink().vm.$emit('click');

      expect(trackingSpy).toHaveBeenCalledWith('projects:learn_gitlab:show', 'click_link', {
        category: 'projects:learn_gitlab:show',
        label: 'add_code',
      });
    });
  });

  describe('computed properties', () => {
    it('generates unique modal IDs', () => {
      createComponent();

      expect(findCommandLineModal().props('modalId')).toMatch(/command-line-modal/);
      expect(findUploadBlobModal().props('modalId')).toMatch(/modal-upload-blob/);
    });

    it('correctly determines canShowUploadButton when user has permissions', () => {
      createComponent({}, { canPushCode: true, canPushToBranch: true });

      expect(findUploadFilesButton().exists()).toBe(true);
      expect(findUploadBlobModal().exists()).toBe(true);
    });

    it('correctly determines canShowUploadButton when user lacks permissions', () => {
      createComponent({}, { canPushCode: false, canPushToBranch: false });

      expect(findUploadFilesButton().exists()).toBe(false);
      expect(findUploadBlobModal().exists()).toBe(false);
    });
  });
});
