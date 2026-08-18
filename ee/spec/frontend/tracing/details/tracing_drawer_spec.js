import { GlDrawer, GlLink } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import TracingDrawer from 'ee/tracing/details/tracing_drawer.vue';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';
import { HTTP_STATUS_OK } from '~/lib/utils/http_status';

jest.mock('~/lib/utils/dom_utils');

describe('TracingDrawer', () => {
  let wrapper;

  const findDrawer = () => wrapper.findComponent(GlDrawer);

  const mockSpan = {
    service_name: 'test-service',
    operation: 'test-operation',
    emptyVal: '',
    span_attributes: {
      'http.status_code': `${HTTP_STATUS_OK}`,
      'http.method': 'GET',
      'http.empty': '',
    },
    resource_attributes: {
      'k8s.namespace.name': 'otel-demo-app',
      'k8s.deployment.name': 'otel-demo-loadgenerator',
      'k8s.deployment.empty': '',
    },
  };

  const mountComponent = ({ open = true, span = mockSpan } = {}) => {
    wrapper = shallowMountExtended(TracingDrawer, {
      propsData: {
        span,
        open,
      },
    });
  };

  const findSection = (sectionId) => {
    const section = wrapper.findByTestId(sectionId);
    const title = section.find('[data-testid="section-title"]').text();
    const lines = section.findAll('[data-testid="section-line"]').wrappers.map((w) => ({
      name: w.find('[data-testid="section-line-name"]').text(),
      value: w.find('[data-testid="section-line-value"]').text(),
    }));
    return {
      title,
      lines,
    };
  };

  const getSectionLineWrapperByName = (name) =>
    wrapper
      .findByTestId('section-span-details')
      .findAll('[data-testid="section-line"]')
      .wrappers.find((w) => w.find('[data-testid="section-line-name"]').text() === name);

  beforeEach(() => {
    mountComponent();
  });

  it('renders the component properly', () => {
    expect(wrapper.exists()).toBe(true);
    expect(findDrawer().exists()).toBe(true);
    expect(findDrawer().props('open')).toBe(true);
  });

  it('emits close', () => {
    findDrawer().vm.$emit('close');
    expect(wrapper.emitted('close')).toHaveLength(1);
  });

  it('displays the correct title', () => {
    expect(wrapper.findByTestId('drawer-title').text()).toBe('test-service : test-operation');
  });

  it.each([
    [
      'section-span-details',
      'Metadata',
      [
        { name: 'operation', value: 'test-operation' },
        { name: 'service_name', value: 'test-service' },
      ],
    ],
    [
      'section-span-attributes',
      'Attributes',
      [
        { name: 'http.method', value: 'GET' },
        { name: 'http.status_code', value: `${HTTP_STATUS_OK}` },
      ],
    ],
    [
      'section-resource-attributes',
      'Resource attributes',
      [
        { name: 'k8s.deployment.name', value: 'otel-demo-loadgenerator' },
        { name: 'k8s.namespace.name', value: 'otel-demo-app' },
      ],
    ],
  ])('displays the %s section in expected order', (sectionId, expectedTitle, expectedLines) => {
    const { title, lines } = findSection(sectionId);
    expect(title).toBe(expectedTitle);
    expect(lines).toEqual(expectedLines);
  });

  it.each([
    ['span_attributes', 'section-span-attributes'],
    ['resource_attributes', 'section-resource-attributes'],
  ])('if %s is missing, it does not render %s', (attrKey, sectionId) => {
    mountComponent({ span: { ...mockSpan, [attrKey]: undefined } });
    expect(wrapper.findByTestId(sectionId).exists()).toBe(false);
  });

  describe('with no span', () => {
    beforeEach(() => {
      mountComponent({ span: null });
    });

    it('displays an empty title', () => {
      expect(wrapper.findByTestId('drawer-title').text()).toBe('');
    });

    it('does not render any section', () => {
      expect(wrapper.findByTestId('section-span-details').exists()).toBe(false);
      expect(wrapper.findByTestId('section-span-attributes').exists()).toBe(false);
      expect(wrapper.findByTestId('section-resource-attributes').exists()).toBe(false);
    });
  });

  it('renders gl-link when a value is a link', () => {
    const link = 'https://gitlab.com/gitlab-org/gitlab/-/pipelines/1090600528';
    mountComponent({
      span: {
        ...mockSpan,
        operation: link,
        service: 'not-a-link',
      },
    });

    expect(getSectionLineWrapperByName('service').findComponent(GlLink).exists()).toBe(false);

    const operation = getSectionLineWrapperByName('operation');
    expect(operation.findComponent(GlLink).exists()).toBe(true);
    expect(operation.findComponent(GlLink).attributes('href')).toBe(link);
  });

  describe('error code', () => {
    it('highlights the status_code section in case of error', () => {
      mountComponent({
        span: {
          ...mockSpan,
          status_code: 'STATUS_CODE_ERROR',
        },
      });

      expect(getSectionLineWrapperByName('status_code').classes()).toContain('gl-bg-red-100');
    });

    it('does not highlight the status_code section if there is no error', () => {
      mountComponent({
        span: {
          ...mockSpan,
          status_code: 'STATUS_CODE_UNSET',
        },
      });

      expect(getSectionLineWrapperByName('status_code').classes()).not.toContain('gl-bg-red-100');
    });
  });

  describe('header height', () => {
    beforeEach(() => {
      getContentWrapperHeight.mockClear();
      getContentWrapperHeight.mockReturnValue(`1234px`);
    });

    it('does not set the header height if not open', () => {
      mountComponent({ open: false });

      expect(findDrawer().props('headerHeight')).toBe('0');
      expect(getContentWrapperHeight).not.toHaveBeenCalled();
    });

    it('sets the header height to match contentWrapperHeight if open', async () => {
      mountComponent({ open: true });
      await nextTick();

      expect(findDrawer().props('headerHeight')).toBe('1234px');
      expect(getContentWrapperHeight).toHaveBeenCalled();
    });
  });
});
