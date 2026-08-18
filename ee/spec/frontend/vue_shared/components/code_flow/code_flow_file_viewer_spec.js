import VueApollo from 'vue-apollo';
import { GlAlert, GlButton, GlSprintf } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import CodeFlowFileViewer from 'ee/vue_shared/components/code_flow/code_flow_file_viewer.vue';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import VulnerabilityFileContentViewer from 'ee/vue_shared/vulnerabilities/components/vulnerability_file_content_viewer.vue';
import BlobFilepath from '~/blob/components/blob_header_filepath.vue';
import { highlightContent } from '~/highlight_js';

Vue.use(VueApollo);

jest.mock('~/highlight_js', () => ({
  highlightContent: jest.fn().mockResolvedValue('highlighted content'),
}));

describe('Vulnerability Code Flow File Viewer component', () => {
  let wrapper;

  const blobData = {
    id: 1,
    rawTextBlob: 'line 1\nline 2\nline 3\nline 4\nline 5',
  };

  const defaultProps = {
    blobInfo: {
      rawTextBlob: blobData.rawTextBlob,
      path: 'samples/test.js',
      webPath: '/path/to/project/-/blob/samples/test.js',
    },
    filePath: 'samples/test.js',
    branchRef: '123',
    hlInfo: [],
    selectedStepNumber: 1,
  };

  const hlInfo = [
    {
      blockStartLine: 1,
      blockEndLine: 5,
      highlightInfo: [
        {
          index: 0,
          startLine: 1,
          endLine: 2,
        },
      ],
    },
  ];

  const hlInfoExpanded = [
    {
      blockStartLine: 2,
      blockEndLine: 7,
      highlightInfo: [
        {
          index: 0,
          startLine: 3,
          endLine: 3,
        },
      ],
    },
  ];

  const createWrapper = (props = {}, mountFn = shallowMountExtended) => {
    wrapper = mountFn(CodeFlowFileViewer, {
      provide: { projectFullPath: 'path/to/project' },
      propsData: {
        blobInfo: defaultProps.blobInfo,
        filePath: defaultProps.filePath,
        branchRef: defaultProps.branchRef,
        hlInfo: defaultProps.hlInfo,
        selectedStepNumber: defaultProps.selectedStepNumber,
        ...props,
      },
      stubs: { GlSprintf, GlButton, BlobFilepath },
    });
  };

  const findVulFileContentViewer = () => wrapper.findComponent(VulnerabilityFileContentViewer);
  const findBlobFilepath = () => wrapper.findComponent(BlobFilepath);
  const findFileTitle = () => wrapper.findByTestId('file-title-content');
  const findGlAlert = () => wrapper.findComponent(GlAlert);
  const findExpandTopButton = () => wrapper.findByTestId('expand-top-lines');
  const findExpandBottomButton = () => wrapper.findByTestId('expand-bottom-lines');
  const findCollapseExpandButton = () => wrapper.findComponentByTestId('collapse-expand-file');

  describe('loading and error states', () => {
    it('shows a warning if the file was not found', () => {
      createWrapper({ blobInfo: {} });

      expect(findGlAlert().text()).toBe(
        `${defaultProps.filePath} was not found in ref ${defaultProps.branchRef}`,
      );
    });

    it('displays an error alert when blobInfo is empty', () => {
      createWrapper({ blobInfo: {} });
      expect(findGlAlert().exists()).toBe(true);
    });
  });

  describe('file contents loaded', () => {
    it('does not render alert without an error', () => {
      createWrapper();
      expect(findGlAlert().exists()).toBe(false);
    });

    it('shows the source code without markdown', () => {
      createWrapper();
      expect(findBlobFilepath().exists()).toBe(true);
      expect(findCollapseExpandButton().exists()).toBe(true);
      expect(findVulFileContentViewer().exists()).toBe(false);
    });

    it('shows the source code with markdown', () => {
      createWrapper({ hlInfo });
      expect(findVulFileContentViewer().exists()).toBe(true);
      expect(findVulFileContentViewer().props()).toMatchObject({
        startLine: hlInfo[0].blockStartLine,
        endLine: hlInfo[0].blockEndLine,
        isHighlighted: false,
        content: blobData.rawTextBlob,
        highlightInfo: hlInfo[0].highlightInfo,
      });
    });

    it('shows a link to the file in the blob header', () => {
      createWrapper(defaultProps, mountExtended);
      expect(findFileTitle().attributes('href')).toBe(defaultProps.blobInfo.webPath);
    });

    it('renders GlButton with correct aria-label when file is expanded', () => {
      createWrapper();
      expect(findCollapseExpandButton().attributes('aria-label')).toBe('Hide file contents');
    });

    it('renders the expand buttons with correct aria-label', () => {
      createWrapper({ hlInfo: hlInfoExpanded });
      expect(findExpandTopButton().attributes('aria-label')).toBe('Expand all lines');
      expect(findExpandBottomButton().attributes('aria-label')).toBe('Expand all lines');
    });

    it('does not render expand line buttons when the first markdown block starts at the first line of content', () => {
      createWrapper({ hlInfo });
      expect(findExpandTopButton().exists()).toBe(false);
    });

    it('does not render expand line buttons when the last markdown block matches content length', () => {
      createWrapper({ hlInfo });
      expect(findExpandBottomButton().exists()).toBe(false);
    });

    it('renders the expand line buttons when the first markdown block does not starts at the first line of content', () => {
      createWrapper({ hlInfo: hlInfoExpanded });
      expect(findExpandTopButton().exists()).toBe(true);
    });

    it('renders expand line buttons when the last markdown block does not matches content length', () => {
      createWrapper({ hlInfo: hlInfoExpanded });
      expect(findExpandBottomButton().exists()).toBe(true);
    });

    it('toggles the blob view when the expand button is clicked', async () => {
      createWrapper({ hlInfo: hlInfoExpanded });
      expect(findVulFileContentViewer().exists()).toBe(true);
      await findCollapseExpandButton().vm.$emit('click');
      expect(findVulFileContentViewer().exists()).toBe(false);
      await findCollapseExpandButton().vm.$emit('click');
      expect(findVulFileContentViewer().exists()).toBe(true);
    });
  });

  describe('escapes content when syntax highlighting fails', () => {
    beforeEach(() => {
      highlightContent.mockResolvedValue(undefined);
    });

    it('escapes html input correctly', async () => {
      const maliciousContent = '<script>alert("xss")</script>';
      createWrapper({
        blobInfo: {
          ...defaultProps.blobInfo,
          rawTextBlob: maliciousContent,
        },
        hlInfo,
      });

      await nextTick();

      expect(wrapper.vm.highlightedContent).not.toContain('<script>');
      expect(wrapper.vm.highlightedContent).toContain('&lt;script&gt;');
      expect(wrapper.vm.highlightedContent).toContain('&lt;/script&gt;');
    });

    it('renders correctly without html tags', async () => {
      const safeContent = 'const x = 1;\nconst y = 2;';
      createWrapper({
        blobInfo: {
          ...defaultProps.blobInfo,
          rawTextBlob: safeContent,
        },
        hlInfo,
      });

      await nextTick();

      expect(wrapper.vm.highlightedContent).toContain('const x = 1;');
      expect(wrapper.vm.highlightedContent).toContain('const y = 2;');
    });
  });
});
