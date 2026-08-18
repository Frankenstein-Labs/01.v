import { GlSprintf, GlPopover, GlCard, GlLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GeoReplicableItemRegistryInfo from 'ee/geo_replicable_item/components/geo_replicable_item_registry_info.vue';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';
import TimeAgo from '~/vue_shared/components/time_ago_tooltip.vue';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';
import { MOCK_REPLICABLE_CLASS, MOCK_REPLICABLE_WITH_VERIFICATION } from '../mock_data';

describe('GeoReplicableItemRegistryInfo', () => {
  let wrapper;

  const defaultProps = {
    replicableItem: MOCK_REPLICABLE_WITH_VERIFICATION,
    registryId: `${MOCK_REPLICABLE_CLASS.graphqlRegistryClass}/${MOCK_REPLICABLE_WITH_VERIFICATION.replicableItemId}`,
    replicableClass: MOCK_REPLICABLE_CLASS,
  };

  const createComponent = ({ props = {} } = {}) => {
    const propsData = {
      ...defaultProps,
      ...props,
    };

    wrapper = shallowMountExtended(GeoReplicableItemRegistryInfo, {
      propsData,
      stubs: {
        GlSprintf,
        GlCard,
      },
    });
  };

  const findHelpIcon = () => wrapper.findComponent(HelpIcon);
  const findGlPopover = () => wrapper.findComponent(GlPopover);
  const findCopyableRegistryInformation = () =>
    wrapper.findAllByTestId('copyable-registry-information');
  const findRegistryInformationCreatedAt = () => wrapper.findComponent(TimeAgo);
  const findModelRecord = () => wrapper.findByTestId('model-record');

  describe('card header', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders help icon', () => {
      expect(findHelpIcon().attributes('id')).toBe('registry-information-help-icon');
    });

    it('renders popover', () => {
      expect(findGlPopover().props('target')).toBe('registry-information-help-icon');
      expect(findGlPopover().text()).toBe(
        'Shows general information about this registry including the various ways it may be referenced.',
      );
    });
  });

  describe('registry information', () => {
    beforeEach(() => {
      createComponent();
    });

    it.each`
      index | title            | value
      ${0}  | ${'Registry ID'} | ${defaultProps.registryId}
      ${1}  | ${'GraphQL ID'}  | ${MOCK_REPLICABLE_WITH_VERIFICATION.id}
    `('renders $title: $value with clipboard button', ({ index, title, value }) => {
      const registryDetails = findCopyableRegistryInformation().at(index);

      expect(registryDetails.text()).toBe(`${title}: ${value}`);
      expect(registryDetails.findComponent(ClipboardButton).props('text')).toBe(String(value));
    });

    it('renders TimeAgo component for createAt', () => {
      expect(findRegistryInformationCreatedAt().props('time')).toBe(
        MOCK_REPLICABLE_WITH_VERIFICATION.createdAt,
      );
    });
  });

  describe('model record information', () => {
    describe('when replicable item has a dataManagementDetailsPath', () => {
      beforeEach(() => {
        createComponent();
      });

      it('renders model record as a link', () => {
        expect(findModelRecord().findComponent(GlLink).props('href')).toBe(
          MOCK_REPLICABLE_WITH_VERIFICATION.dataManagementDetailsPath,
        );
        expect(findModelRecord().text()).toBe(
          `Model record: ${MOCK_REPLICABLE_CLASS.modelClassName}/${MOCK_REPLICABLE_WITH_VERIFICATION.modelRecordId}`,
        );
      });

      it('renders a clipboard button with correct value', () => {
        expect(findModelRecord().findComponent(ClipboardButton).props('text')).toBe(
          `${MOCK_REPLICABLE_CLASS.modelClassName}/${MOCK_REPLICABLE_WITH_VERIFICATION.modelRecordId}`,
        );
      });
    });

    describe('when replicable item does not have a dataManagementDetailsPath', () => {
      beforeEach(() => {
        createComponent({
          props: {
            replicableItem: {
              ...MOCK_REPLICABLE_WITH_VERIFICATION,
              dataManagementDetailsPath: null,
            },
          },
        });
      });

      it('renders model record as static text', () => {
        expect(findModelRecord().findComponent(GlLink).exists()).toBe(false);
        expect(findModelRecord().text()).toBe(
          `Model record: ${MOCK_REPLICABLE_CLASS.modelClassName}/${MOCK_REPLICABLE_WITH_VERIFICATION.modelRecordId}`,
        );
      });

      it('renders a clipboard button with correct value', () => {
        expect(findModelRecord().findComponent(ClipboardButton).props('text')).toBe(
          `${MOCK_REPLICABLE_CLASS.modelClassName}/${MOCK_REPLICABLE_WITH_VERIFICATION.modelRecordId}`,
        );
      });
    });
  });
});
