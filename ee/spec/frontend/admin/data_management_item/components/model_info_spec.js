import { GlCard, GlSprintf } from '@gitlab/ui';
import models from 'test_fixtures/api/admin/data_management/snippet_repositories.json';
import ModelInfo from 'ee/admin/data_management_item/components/model_info.vue';
import TimeAgo from '~/vue_shared/components/time_ago_tooltip.vue';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('ModelInfo', () => {
  let wrapper;

  const [rawModel] = models;
  const model = convertObjectPropsToCamelCase(rawModel, { deep: true });

  const defaultProps = { model };

  const createComponent = ({ props } = { props: {} }) => {
    wrapper = shallowMountExtended(ModelInfo, {
      propsData: { ...defaultProps, ...props },
      stubs: { GlCard, GlSprintf },
    });
  };

  const findHeading = () => wrapper.find('h5');
  const findModelId = () => wrapper.findByTestId('model-id');
  const findSize = () => wrapper.findByTestId('size');
  const findCreatedAt = () => wrapper.findByTestId('created-at');

  it('renders card header', () => {
    createComponent();

    expect(findHeading().text()).toContain('Model information');
  });

  it('renders model id', () => {
    createComponent();

    expect(findModelId().text()).toBe(`Model ID: ${model.recordIdentifier}`);
    expect(findModelId().findComponent(ClipboardButton).props()).toEqual(
      expect.objectContaining({
        title: 'Copy',
        text: String(model.recordIdentifier),
      }),
    );
  });

  describe('when fileSize is defined', () => {
    it('renders fileSize', () => {
      createComponent({ props: { model: { ...model, fileSize: 1024 } } });

      expect(findSize().text()).toBe('Storage: 1.00 KiB');
    });
  });

  describe('when fileSize is unknown', () => {
    it('renders unknown', () => {
      createComponent({ props: { model: { ...model, fileSize: null } } });

      expect(findSize().text()).toBe('Storage: Unknown');
    });
  });

  describe('when createdAt is defined', () => {
    it('renders createdAt', () => {
      createComponent({ props: { model: { ...model, createdAt: '2024-01-01T00:00:00Z' } } });

      expect(findCreatedAt().text()).toContain('Created:');
      expect(findCreatedAt().findComponent(TimeAgo).props('time')).toBe('2024-01-01T00:00:00Z');
    });
  });

  describe('when createdAt is unknown', () => {
    it('renders unknown', () => {
      createComponent({ props: { model: { ...model, createdAt: null } } });

      expect(findCreatedAt().text()).toBe('Created: Unknown');
    });
  });
});
