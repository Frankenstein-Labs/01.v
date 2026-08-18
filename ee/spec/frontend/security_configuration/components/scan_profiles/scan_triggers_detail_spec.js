import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import ScanTriggersDetail from 'ee/security_configuration/components/scan_profiles/scan_triggers_detail.vue';
import { SCAN_TRIGGER_DEFINITIONS } from '~/security_configuration/constants';

const ALL_TRIGGERS = Object.values(SCAN_TRIGGER_DEFINITIONS);

describe('ScanTriggersDetail', () => {
  let wrapper;

  const findAllCruds = () => wrapper.findAllComponents(CrudComponent);
  const findCrudAt = (index) => findAllCruds().at(index);
  const findAllDocsButtons = () => wrapper.findAllComponents(GlButton);

  describe('Secret detection', () => {
    beforeEach(() => {
      wrapper = shallowMountExtended(ScanTriggersDetail, {
        propsData: { triggers: ALL_TRIGGERS },
      });
    });

    it('renders all 3 triggers', () => {
      expect(findAllCruds()).toHaveLength(3);
    });

    describe('Secret push protection trigger', () => {
      it('renders CrudComponent with correct props', () => {
        expect(findCrudAt(0).props()).toMatchObject({
          isCollapsible: true,
          collapsed: true,
          description: 'Scan all Git push events and block pushes with detected secrets.',
          anchorId: 'secret-push-protection',
        });
      });

      it('does not pass icon prop to CrudComponent', () => {
        expect(findCrudAt(0).props('icon')).toBeNull();
      });

      it('renders description text', () => {
        expect(findCrudAt(0).text()).toContain(
          'Block secrets such as keys and API tokens from being pushed to your repositories.',
        );
      });

      it('renders documentation button with default variant', () => {
        const button = findAllDocsButtons().at(0);

        expect(button.props()).toMatchObject({
          variant: 'default',
          size: 'small',
          href: '/help/user/application_security/secret_detection/secret_push_protection/_index.md',
        });
        expect(button.attributes('target')).toBe('_blank');
        expect(button.text()).toBe('View documentation');
      });
    });

    describe('Merge request pipeline trigger', () => {
      it('renders CrudComponent with correct props', () => {
        expect(findCrudAt(1).props()).toMatchObject({
          isCollapsible: true,
          collapsed: true,
          description: 'Scans new commits to merge requests · All branches',
          anchorId: 'merge-request-pipeline',
        });
      });

      it('renders target branch, scope and results metadata', () => {
        const text = findCrudAt(1).text();

        expect(text).toContain('Target branch:');
        expect(text).toContain('All');
        expect(text).toContain('Scope:');
        expect(text).toContain('Full repository');
        expect(text).toContain('Results:');
        expect(text).toContain('New vulnerabilities only');
      });
    });

    describe('Default branch pipeline trigger', () => {
      it('renders CrudComponent with correct props', () => {
        expect(findCrudAt(2).props()).toMatchObject({
          isCollapsible: true,
          collapsed: true,
          description: 'Scans commits to the default branch',
          anchorId: 'default-branch-pipeline',
        });
      });

      it('renders target branch, scope and results metadata', () => {
        const text = findCrudAt(2).text();

        expect(text).toContain('Target branch:');
        expect(text).toContain('Default');
        expect(text).toContain('Scope:');
        expect(text).toContain('Full repository');
        expect(text).toContain('Results:');
        expect(text).toContain('All vulnerabilities');
      });
    });
  });
});
