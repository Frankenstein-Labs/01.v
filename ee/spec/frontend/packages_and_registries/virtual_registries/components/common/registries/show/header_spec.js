import { GlButton, GlDisclosureDropdown, GlDisclosureDropdownItem } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import TitleArea from '~/vue_shared/components/registry/title_area.vue';
import MetadataItem from '~/vue_shared/components/registry/metadata_item.vue';
import RegistryDetailsHeader from 'ee/packages_and_registries/virtual_registries/components/common/registries/show/header.vue';
import MavenI18n from 'ee/packages_and_registries/virtual_registries/pages/maven/i18n';

describe('RegistryDetailsHeader', () => {
  let wrapper;

  const defaultProps = {
    registry: {
      id: 1,
      name: 'Registry title',
      description: 'Registry description',
    },
  };

  const defaultProvide = {
    i18n: MavenI18n,
    maxRegistryUpstreamsCount: 20,
  };

  const findEditButton = () => wrapper.findComponent(GlButton);
  const findTitleArea = () => wrapper.findComponent(TitleArea);
  const findMetadataItem = () => wrapper.findComponent(MetadataItem);
  const findDescription = () => wrapper.findByTestId('description');
  const findDropdown = () => wrapper.findComponent(GlDisclosureDropdown);
  const findDropdownItem = () => wrapper.findComponent(GlDisclosureDropdownItem);
  const mockToast = {
    show: jest.fn(),
  };

  const createComponent = ({ provide = {} } = {}) => {
    wrapper = shallowMountExtended(RegistryDetailsHeader, {
      propsData: {
        ...defaultProps,
      },
      provide: {
        ...defaultProvide,
        ...provide,
      },
      stubs: {
        TitleArea,
      },
      mocks: {
        $toast: mockToast,
      },
    });
  };

  describe('default', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the TitleArea component with correct props', () => {
      expect(findTitleArea().props('title')).toBe('Registry title');
    });

    it('renders the description', () => {
      expect(findDescription().text()).toBe('Registry description');
    });

    it('displays metadata items', () => {
      expect(findMetadataItem().props('icon')).toBe('infrastructure-registry');
      expect(findMetadataItem().props('text')).toBe('Maven');
    });

    it('does not render Edit button', () => {
      expect(findEditButton().exists()).toBe(false);
    });

    it('renders sub-header with upstreams limit information', () => {
      expect(wrapper.text()).toContain('You can add up to 20 upstreams per registry.');
    });

    it('renders dropdown with correct props', () => {
      expect(findDropdown().props()).toMatchObject({
        category: 'tertiary',
        icon: 'ellipsis_v',
        noCaret: true,
        toggleText: 'More actions',
        textSrOnly: true,
      });
    });

    it('renders dropdown item with copy ID functionality', () => {
      const dropdownItem = findDropdownItem();
      expect(dropdownItem.text()).toBe('Copy virtual registry ID: 1');
      expect(dropdownItem.attributes('data-clipboard-text')).toBe('1');
    });

    describe('dropdown tooltip behavior', () => {
      it('shows tooltip initially', () => {
        expect(findDropdown().attributes('title')).toBe('More actions');
      });

      it('removes tooltip when dropdown is shown', async () => {
        const dropdown = findDropdown();
        await dropdown.vm.$emit('shown');

        expect(dropdown.attributes('title')).toBe('');
      });

      it('restores tooltip when dropdown is hidden', async () => {
        const dropdown = findDropdown();
        await dropdown.vm.$emit('shown');
        await dropdown.vm.$emit('hidden');

        expect(dropdown.attributes('title')).toBe('More actions');
      });
    });

    describe('copy ID action', () => {
      it('shows toast message when copy action is triggered', async () => {
        await findDropdownItem().vm.$emit('action');

        expect(mockToast.show).toHaveBeenCalledWith('Virtual registry ID copied to clipboard.');
      });
    });
  });

  describe('when user has ability to edit', () => {
    beforeEach(() => {
      createComponent({
        provide: {
          registryEditPath: 'registry_edit_path',
          glAbilities: {
            updateVirtualRegistry: true,
          },
        },
      });
    });

    it('renders Edit button', () => {
      expect(findEditButton().text()).toBe('Edit');
      expect(findEditButton().props('href')).toBe('registry_edit_path');
    });

    it('renders `More actions` dropdown', () => {
      expect(findDropdown().exists()).toBe(true);
    });
  });
});
