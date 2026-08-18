import { GlCollapsibleListbox, GlButton, GlSprintf } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import DenyAllowList from 'ee/security_orchestration/components/policy_editor/scan_result/rule/deny_allow_list.vue';
import DenyAllowListModal from 'ee/security_orchestration/components/policy_editor/scan_result/rule/deny_allow_list_modal.vue';
import {
  DENIED,
  ALLOWED,
} from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/constants';

describe('DenyAllowList', () => {
  let wrapper;

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMount(DenyAllowList, {
      propsData: props,
      stubs: {
        GlSprintf,
      },
    });
  };

  const findTypeDropdown = () => wrapper.findComponent(GlCollapsibleListbox);
  const findModal = () => wrapper.findComponent(DenyAllowListModal);
  const findButton = () => wrapper.findComponent(GlButton);
  const findSectionLayout = () => wrapper.findComponent(SectionLayout);

  describe('default state', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders deny list by default', () => {
      expect(findTypeDropdown().props('selected')).toBe(DENIED);
      expect(findTypeDropdown().props('toggleText')).toBe('Denied');
      expect(findButton().text()).toBe('denylist (0 licenses)');
    });

    it('emits select type event', () => {
      findTypeDropdown().vm.$emit('select', ALLOWED);

      expect(wrapper.emitted('select-type')).toEqual([[ALLOWED]]);
    });
  });

  describe('error state', () => {
    it('renders error state', () => {
      createComponent({
        props: { hasError: true },
      });

      expect(findSectionLayout().classes()).toContain('gl-border-red-400');
    });
  });

  describe('single license', () => {
    it('renders allowlist with single license', () => {
      createComponent({
        props: {
          selected: ALLOWED,
          licenses: ['package-1'],
        },
      });

      expect(findTypeDropdown().props('selected')).toBe(ALLOWED);
      expect(findTypeDropdown().props('toggleText')).toBe('Allowed');
      expect(findButton().text()).toBe('allowlist (1 license)');
    });
  });

  describe('multiple licenses', () => {
    it('renders denylist with multiple licenses', () => {
      createComponent({
        props: {
          licenses: ['package-1', 'package-2'],
        },
      });

      expect(findTypeDropdown().props('selected')).toBe(DENIED);
      expect(findTypeDropdown().props('toggleText')).toBe('Denied');
      expect(findButton().text()).toBe('denylist (2 licenses)');
    });
  });

  describe('deny allow modal', () => {
    it('renders denylist modal', () => {
      createComponent();

      expect(findModal().exists()).toBe(true);
      expect(findModal().props('listType')).toBe(DENIED);
    });
  });

  describe('select licenses', () => {
    const LICENSES = [
      {
        text: 'License 1',
        value: 'license_1',
      },
      {
        text: 'License 2',
        value: 'license_2',
      },
    ];

    it('selects licenses', () => {
      createComponent();

      findModal().vm.$emit('select-licenses', LICENSES);

      expect(wrapper.emitted('select-licenses')).toEqual([[LICENSES]]);
    });

    it('renders selected licenses', () => {
      createComponent({
        props: {
          licenses: LICENSES,
        },
      });

      expect(findModal().props('licenses')).toEqual(LICENSES);
    });
  });
});
