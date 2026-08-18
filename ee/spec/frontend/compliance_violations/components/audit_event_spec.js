import { GlAnimatedChevronLgRightDownIcon, GlCollapse, GlDrawer } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import AuditEvent from 'ee/compliance_violations/components/audit_event.vue';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import { humanize } from '~/lib/utils/text_utility';
import { formatDate } from '~/lib/utils/datetime_utility';

describe('AuditEvent', () => {
  let wrapper;

  const mockAuditEvent = {
    id: 'gid://gitlab/AuditEvent/123',
    eventName: 'merge_request_merged',
    entityType: 'Project',
    entityId: '456',
    entityPath: 'group/project',
    targetId: '789',
    targetType: 'MergeRequest',
    createdAt: '2023-01-01T00:00:00Z',
    details: '{"custom_field": "custom_value", "another_field": "another_value"}',
    author: {
      id: 'gid://gitlab/User/1',
      name: 'John Doe',
    },
    ipAddress: '192.168.1.1',
  };

  const createComponent = (props = {}) => {
    wrapper = mountExtended(AuditEvent, {
      propsData: {
        auditEvent: mockAuditEvent,
        ...props,
      },
    });
  };

  const findAuditEventSection = () => wrapper.findComponent(CrudComponent);
  const findGlLink = () => wrapper.findComponentByTestId('audit-event-drawer-link');
  const findDrawer = () => wrapper.findComponent(GlDrawer);
  const findDrawerDescription = () => wrapper.findByTestId('audit-event-drawer-description');
  const findDetailsToggle = () => wrapper.findByTestId('audit-event-details-toggle');
  const findChevronIcon = () => wrapper.findComponent(GlAnimatedChevronLgRightDownIcon);
  const findDetailsCollapse = () => wrapper.findComponent(GlCollapse);

  beforeEach(() => {
    createComponent();
  });

  describe('audit event section', () => {
    it('renders audit event section', () => {
      expect(findAuditEventSection().exists()).toBe(true);
    });

    it('renders the correct title', () => {
      const titleElement = wrapper.findByTestId('crud-title');
      expect(titleElement.text()).toBe('Audit event captured');
    });

    it('renders GlLink with correct content', () => {
      const link = findGlLink();
      expect(link.exists()).toBe(true);
      expect(link.text()).toContain(mockAuditEvent.author.name);
      expect(link.text()).toContain(mockAuditEvent.entityType);
      expect(link.text()).toContain(humanize(mockAuditEvent.eventName));
    });

    it('renders IP address information', () => {
      expect(wrapper.text()).toContain('Registered event IP');
      expect(wrapper.text()).toContain(mockAuditEvent.ipAddress);
    });
  });

  describe('drawer functionality', () => {
    it('renders drawer component', () => {
      expect(findDrawer().exists()).toBe(true);
    });

    it('drawer is initially closed', () => {
      expect(findDrawer().props('open')).toBe(false);
    });

    it('opens drawer when link is clicked', async () => {
      await findGlLink().vm.$emit('click');

      expect(findDrawer().props('open')).toBe(true);
    });

    it('closes drawer when close event is emitted', async () => {
      await findGlLink().vm.$emit('click');
      expect(findDrawer().props('open')).toBe(true);

      await findDrawer().vm.$emit('close');
      expect(findDrawer().props('open')).toBe(false);
    });

    it('renders drawer title with event name', async () => {
      await findGlLink().vm.$emit('click');

      const drawerTitle = wrapper.findByTestId('audit-event-drawer-title');
      expect(drawerTitle.text()).toBe(humanize(mockAuditEvent.eventName));
    });

    it('renders summary section in drawer', async () => {
      await findGlLink().vm.$emit('click');

      const summarySection = wrapper.findByTestId('audit-event-drawer-summary').text();
      expect(summarySection).toContain('Summary');
      expect(summarySection).toContain(mockAuditEvent.author.name);
      expect(summarySection).toContain(humanize(mockAuditEvent.eventName));
      expect(summarySection).toContain(mockAuditEvent.entityType);
    });

    it('renders description section in drawer', async () => {
      await findGlLink().vm.$emit('click');

      const descriptionSection = findDrawerDescription().text();
      expect(descriptionSection).toContain('Description');

      expect(descriptionSection).toContain('Author name:');
      expect(descriptionSection).toContain('John Doe');

      expect(descriptionSection).toContain('Created at:');
      expect(descriptionSection).toContain(formatDate(mockAuditEvent.createdAt));

      expect(descriptionSection).toContain('Entity ID:');
      expect(descriptionSection).toContain('456');

      expect(descriptionSection).toContain('Entity path:');
      expect(descriptionSection).toContain('group/project');

      expect(descriptionSection).toContain('Entity type:');
      expect(descriptionSection).toContain('Project');

      expect(descriptionSection).toContain('Event name:');
      expect(descriptionSection).toContain('Merge request merged');

      expect(descriptionSection).toContain('IP address:');
      expect(descriptionSection).toContain('192.168.1.1');

      expect(descriptionSection).toContain('Target ID:');
      expect(descriptionSection).toContain('789');

      expect(descriptionSection).toContain('Target type:');
      expect(descriptionSection).toContain('MergeRequest');
    });
  });

  describe('description field filtering', () => {
    it('does not render null or empty fields in description', async () => {
      const auditEventWithNulls = {
        ...mockAuditEvent,
        author: null,
        ipAddress: null,
        entityPath: '',
        targetId: null,
      };

      createComponent({ auditEvent: auditEventWithNulls });
      await findGlLink().vm.$emit('click');

      const descriptionText = findDrawerDescription().text();
      expect(descriptionText).not.toContain('Author name:');
      expect(descriptionText).not.toContain('IP address:');
      expect(descriptionText).not.toContain('Entity path:');
      expect(descriptionText).not.toContain('Target ID:');
    });

    it('renders only non-null fields in description', async () => {
      const auditEventPartial = {
        eventName: 'test_event',
        entityType: 'Project',
        entityId: '123',
        createdAt: '2023-01-01T00:00:00Z',
        details: '{"test": "value"}',
        author: {
          id: 'gid://gitlab/User/1',
          name: 'Test User',
        },
      };

      createComponent({ auditEvent: auditEventPartial });
      await findGlLink().vm.$emit('click');

      const descriptionText = findDrawerDescription().text();
      expect(descriptionText).toContain('Author name:');
      expect(descriptionText).toContain('Test User');

      expect(descriptionText).toContain('Entity type:');
      expect(descriptionText).toContain('Project');

      expect(descriptionText).toContain('Entity ID:');
      expect(descriptionText).toContain('123');

      expect(descriptionText).not.toContain('IP address:');
      expect(descriptionText).not.toContain('Entity path:');
      expect(descriptionText).not.toContain('Target ID:');
    });

    describe('details section', () => {
      it('renders details section with toggle', async () => {
        await findGlLink().vm.$emit('click');

        const drawerDetails = findDetailsToggle();
        expect(drawerDetails.exists()).toBe(true);
        expect(drawerDetails.text()).toContain('Details');
        expect(findChevronIcon().exists()).toBe(true);
      });

      it('details section is initially collapsed', async () => {
        await findGlLink().vm.$emit('click');

        expect(findDetailsCollapse().props('visible')).toBe(false);
        expect(findChevronIcon().props('isOn')).toBe(false);
      });

      it('expands details section when toggle is clicked', async () => {
        await findGlLink().vm.$emit('click');
        await findDetailsToggle().trigger('click');

        expect(findDetailsCollapse().props('visible')).toBe(true);
        expect(findChevronIcon().props('isOn')).toBe(true);
      });

      it('collapses details section when toggle is clicked again', async () => {
        await findGlLink().vm.$emit('click');
        await findDetailsToggle().trigger('click');
        expect(findDetailsCollapse().props('visible')).toBe(true);

        await findDetailsToggle().trigger('click');
        expect(findDetailsCollapse().props('visible')).toBe(false);
        expect(findChevronIcon().props('isOn')).toBe(false);
      });

      it('renders parsed details content when expanded', async () => {
        await findGlLink().vm.$emit('click');
        await findDetailsToggle().trigger('click');

        const detailsText = findDetailsCollapse().text();
        expect(detailsText).toContain('custom_field:');
        expect(detailsText).toContain('custom_value');

        expect(detailsText).toContain('another_field:');
        expect(detailsText).toContain('another_value');
      });
    });
  });
});
