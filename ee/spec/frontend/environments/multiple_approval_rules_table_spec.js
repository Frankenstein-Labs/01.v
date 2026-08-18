import { GlTableLite, GlAvatar, GlAvatarLink, GlFormRadio } from '@gitlab/ui';
import mockDeploymentFixture from 'test_fixtures/graphql/environments/graphql/queries/deployment.query.graphql.json';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import MultipleApprovalRulesTable from 'ee/environments/components/multiple_approval_rules_table.vue';
import { stubComponent } from 'helpers/stub_component';

describe('ee/environments/components/multiple_approval_rules_table.vue', () => {
  let wrapper;
  const { rules } = mockDeploymentFixture.data.project.deployment.approvalSummary;

  const createWrapper = ({ propsData = {} } = {}) =>
    mountExtended(MultipleApprovalRulesTable, {
      propsData: { rules, ...propsData },
      stubs: {
        GlFormRadio: stubComponent(GlFormRadio, {
          props: ['checked'],
        }),
      },
    });

  const findTable = () => wrapper.findComponent(GlTableLite);

  const findDataRows = () => {
    const table = findTable();
    // Drop Header Row
    const [, ...rows] = table.findAll('tr').wrappers;
    return rows;
  };

  const findRadioButtons = () => wrapper.findAllComponents(GlFormRadio);

  describe('rules', () => {
    beforeEach(() => {
      wrapper = createWrapper();
    });

    it('should show a row for each rule', () => {
      const rows = findDataRows();

      expect(rows).toHaveLength(rules.length);
    });

    it('should link to group via name', () => {
      const { name, webUrl } = rules.find((rule) => rule.group).group;

      const groupLink = wrapper.findByRole('link', { name });

      expect(groupLink.attributes('href')).toBe(webUrl);
    });

    it('should link user via name', () => {
      const { name, webUrl } = rules.find((rule) => rule.user).user;

      const userLink = wrapper.findByRole('link', { name });

      expect(userLink.attributes('href')).toBe(webUrl);
    });

    it('should show access level for maintainers', () => {
      const cell = wrapper.findByRole('cell', { name: 'Maintainers' });
      expect(cell.exists()).toBe(true);
    });

    it('should show access level for developers', () => {
      const cell = wrapper.findByRole('cell', {
        name: 'Developers + Maintainers',
      });
      expect(cell.exists()).toBe(true);
    });

    it('should show number of approvals out of required approval count', () => {
      const cell = wrapper.findByRole('cell', { name: '1/1' });

      expect(cell.exists()).toBe(true);
    });

    it('should show an avatar for all approvals', () => {
      const avatars = wrapper.findAllComponents(GlAvatar);
      const avatarLinks = wrapper.findAllComponents(GlAvatarLink);
      const approvals = rules
        .flatMap((rule) => rule.approvals)
        .filter((a) => a.status === 'APPROVED');

      approvals.forEach((approval, index) => {
        const avatar = avatars.wrappers[index];
        const avatarLink = avatarLinks.wrappers[index];
        const { user } = approval;

        expect(avatar.props('src')).toBe(user.avatarUrl);
        expect(avatarLink.attributes()).toMatchObject({
          href: user.webUrl,
          title: user.name,
        });
      });
    });

    it('should not show avatars for rejected approvals', () => {
      const rejectedApprovals = rules
        .flatMap((rule) => rule.approvals)
        .filter((a) => a.status === 'REJECTED');
      const avatarLinks = wrapper.findAllComponents(GlAvatarLink);
      const renderedHrefs = avatarLinks.wrappers.map((link) => link.attributes('href'));

      rejectedApprovals.forEach((approval) => {
        expect(renderedHrefs).not.toContain(approval.user.webUrl);
      });
    });

    it('should render row for private group', () => {
      const cell = wrapper.findByTestId('private-group-rule');
      expect(cell.text()).toBe('Private group');
      expect(cell.attributes('title')).toBe(
        'You do not have access to this group, but members of this group can approve this rule.',
      );
    });
  });

  describe('approvals', () => {
    const getRuleName = (index) => rules[index].group?.name || rules[index].user?.name;
    const firstRuleName = getRuleName(0);
    const secondRuleName = getRuleName(1);

    describe('default', () => {
      beforeEach(() => {
        wrapper = createWrapper();
      });

      it('should render a column for giving approval', () => {
        const column = wrapper.findByRole('columnheader', { name: 'Give approval' });

        expect(column.exists()).toBe(true);
      });

      it('should render radio button for each rule the user can approve as', () => {
        const canApproveRules = rules.filter((rule) => rule.canApprove);

        expect(findRadioButtons()).toHaveLength(canApproveRules.length);
      });

      it('should preselect first radio button if no value was selected', () => {
        expect(findRadioButtons().at(0).props('checked')).toBe(firstRuleName);
      });

      it('should emit first applicable rule as selected by default', () => {
        expect(wrapper.emitted('select-rule')).toEqual([[firstRuleName]]);
      });
    });

    describe('when user selects rule', () => {
      beforeEach(() => {
        wrapper = createWrapper();
        findRadioButtons().at(1).vm.$emit('input', secondRuleName);
      });

      it('should deselect first radio button if no value was selected', () => {
        expect(findRadioButtons().at(0).props('checked')).not.toBe(firstRuleName);
      });

      it('should emit selected rule', () => {
        expect(wrapper.emitted('select-rule').at(-1)).toEqual([secondRuleName]);
      });
    });

    describe('when user already approved', () => {
      beforeEach(() => {
        gon.current_username = 'my-user';
        wrapper = createWrapper();
      });

      it('should disable radio buttons', () => {
        findRadioButtons().wrappers.forEach((button) => {
          expect(button.attributes('disabled')).toBeDefined();
        });
      });

      it('should not emit any selected rule', () => {
        expect(wrapper.emitted('select-rule')).toBeUndefined();
      });
    });
  });

  it('should stack on smaller devices', () => {
    wrapper = createWrapper();

    expect(findTable().classes()).toContain('b-table-stacked-lg');
  });
});
