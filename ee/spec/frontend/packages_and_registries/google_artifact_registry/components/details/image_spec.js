import { GlBadge, GlSkeletonLoader, GlTruncate } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { localeDateFormat } from '~/lib/utils/datetime_utility';
import ArtifactRegistryImageDetails from 'ee_component/packages_and_registries/google_artifact_registry/components/details/image.vue';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';
import { imageData, imageDetailsFields } from '../../mock_data';

describe('ArtifactRegistryImageDetails', () => {
  let wrapper;

  const defaultProps = {
    data: {
      ...imageData,
      ...imageDetailsFields,
    },
    isLoading: false,
  };

  const findClipboardButton = () => wrapper.findComponent(ClipboardButton);
  const findLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findAllTags = () => wrapper.findByTestId('tags').findAllComponents(GlBadge);
  const findList = () => wrapper.findByTestId('image-details');

  const createComponent = ({ propsData = defaultProps } = {}) => {
    wrapper = shallowMountExtended(ArtifactRegistryImageDetails, {
      propsData,
    });
  };

  it('renders loader when isLoading is true', () => {
    createComponent({ propsData: { ...defaultProps, isLoading: true } });

    expect(findLoader().exists()).toBe(true);
    expect(findList().exists()).toBe(false);
  });

  it('renders list when isLoading is false', () => {
    createComponent();

    expect(findLoader().exists()).toBe(false);
    expect(findList().exists()).toBe(true);
  });

  it.each(['mediaType', 'projectId', 'location', 'repository', 'image', 'digest'])(
    'renders %s',
    (field) => {
      createComponent();

      expect(wrapper.findByTestId(field).text()).toContain(defaultProps.data[field]);
    },
  );

  it('renders clipboard button for digest', () => {
    createComponent();

    expect(findClipboardButton().props()).toMatchObject({
      size: 'small',
      text: defaultProps.data.digest,
      title: 'Copy digest',
    });
  });

  it.each(['buildTime', 'uploadTime', 'updateTime'])('renders formatted %s', (field) => {
    createComponent();

    expect(wrapper.findByTestId(field).text()).toContain(
      localeDateFormat.asDateTimeFull.format(defaultProps.data[field]),
    );
  });

  describe('nullable fields', () => {
    it.each(['mediaType', 'buildTime', 'uploadTime', 'updateTime'])(
      'renders empty string for %s',
      (field) => {
        createComponent({
          propsData: { ...defaultProps, data: { ...defaultProps.data, [field]: null } },
        });

        expect(wrapper.findByTestId(field).text()).toBe('');
      },
    );
  });

  it('renders size', () => {
    createComponent();

    expect(findList().text()).toContain('2.70 MiB');
  });

  it('renders tags', () => {
    createComponent();

    expect(findAllTags()).toHaveLength(3);
    expect(findAllTags().at(0).findComponent(GlTruncate).props()).toMatchObject({
      text: 'latest',
      withTooltip: true,
    });
    expect(findAllTags().at(1).findComponent(GlTruncate).props()).toMatchObject({
      text: 'v1.0.0',
      withTooltip: true,
    });
    expect(findAllTags().at(2).findComponent(GlTruncate).props()).toMatchObject({
      text: 'v1.0.1',
      withTooltip: true,
    });
  });
});
