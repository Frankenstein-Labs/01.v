import {
  GlButton,
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlSkeletonLoader,
} from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AddUpstream from 'ee/packages_and_registries/virtual_registries/components/common/registries/show/add_upstream.vue';

describe('AddUpstream', () => {
  let wrapper;

  const findAddUpstreamButton = () => wrapper.findComponent(GlButton);
  const findAddUpstreamDropdown = () => wrapper.findComponent(GlDisclosureDropdown);
  const findAddUpstreamDropdownItems = () => wrapper.findAllComponents(GlDisclosureDropdownItem);
  const findLoader = () => wrapper.findComponent(GlSkeletonLoader);

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(AddUpstream, {
      propsData: {
        ...props,
      },
    });
  };

  describe('default', () => {
    beforeEach(() => {
      createComponent();
    });

    it('does not render loader', () => {
      expect(findLoader().exists()).toBe(false);
    });

    it('renders `Add upstream` button', () => {
      expect(findAddUpstreamButton().text()).toBe('Add upstream');
    });

    it('does not render `Add upstream` dropdown', () => {
      expect(findAddUpstreamDropdown().exists()).toBe(false);
    });

    it('clicking on `Add upstream` button emits `create` event', () => {
      findAddUpstreamButton().vm.$emit('click');

      expect(wrapper.emitted('create')).toHaveLength(1);
    });

    describe('and disabled is set to true', () => {
      beforeEach(() => {
        createComponent({ props: { canCreate: true, disabled: true } });
      });

      it('disables the `Add upstream` dropdown', () => {
        expect(findAddUpstreamButton().props('disabled')).toBe(true);
      });
    });
  });

  describe('when loading is set to true', () => {
    beforeEach(() => {
      createComponent({ props: { loading: true } });
    });

    it('renders loader', () => {
      expect(findLoader().exists()).toBe(true);
    });

    it('does not render `Add upstream` button', () => {
      expect(findAddUpstreamButton().exists()).toBe(false);
    });

    it('does not render `Add upstream` dropdown', () => {
      expect(findAddUpstreamDropdown().exists()).toBe(false);
    });
  });

  describe('when canLink is set to true', () => {
    beforeEach(() => {
      createComponent({ props: { canLink: true } });
    });

    it('does not render loader', () => {
      expect(findLoader().exists()).toBe(false);
    });

    it('does not render `Add upstream` button', () => {
      expect(findAddUpstreamButton().exists()).toBe(false);
    });

    it('renders `Add upstream` dropdown', () => {
      expect(findAddUpstreamDropdown().exists()).toBe(true);
    });

    it('renders `Create new upstream` dropdown item', () => {
      expect(findAddUpstreamDropdownItems().at(0).text()).toBe('Create new upstream');
    });

    it('clicking on `Create new upstream` dropdown item emits `create` event', () => {
      findAddUpstreamDropdownItems().at(0).vm.$emit('action');

      expect(wrapper.emitted('create')).toHaveLength(1);
    });

    it('renders `Link existing upstream` dropdown item', () => {
      expect(findAddUpstreamDropdownItems().at(1).text()).toBe('Link existing upstream');
    });

    it('clicking on `Link existing upstream` dropdown item emits `link` event', () => {
      findAddUpstreamDropdownItems().at(1).vm.$emit('action');

      expect(wrapper.emitted('link')).toHaveLength(1);
    });

    describe('and disabled is set to true', () => {
      beforeEach(() => {
        createComponent({ props: { canLink: true, disabled: true } });
      });

      it('disables the `Add upstream` dropdown', () => {
        expect(findAddUpstreamDropdown().props('disabled')).toBe(true);
      });
    });
  });
});
