import { GlAvatarLink, GlAvatar, GlBadge } from '@gitlab/ui';
import mockDeploymentFixture from 'test_fixtures/ee/graphql/deployments/graphql/queries/deployment.query.graphql.json';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import DeploymentTimeline from 'ee/deployments/components/deployment_timeline.vue';
import { ACCESS_LEVEL } from 'ee/deployments/constants';

const { approvalSummary } = mockDeploymentFixture.data.project.deployment;

describe('ee/deployments/components/deployment_timeline.vue', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(DeploymentTimeline, {
      propsData: { approvalSummary },
    });
  };

  const getAllApprovals = () => approvalSummary.rules.flatMap((rule) => rule.approvals);
  const findApproval = (username) => wrapper.findByTestId(`approval-${username}`);
  const findApprovalComment = (username) => wrapper.findByTestId(`approval-comment-${username}`);

  beforeEach(() => {
    createComponent();
  });

  it('shows all approvals', () => {
    getAllApprovals().forEach(({ user }) => {
      expect(findApproval(user.username).exists()).toBe(true);
    });
  });

  it('shows the user who made the approval', () => {
    getAllApprovals().forEach(({ user }) => {
      const approvalBlock = findApproval(user.username);
      const avatarLink = approvalBlock.findComponent(GlAvatarLink);
      expect(avatarLink.attributes('href')).toBe(user.webUrl);

      const avatar = approvalBlock.findComponent(GlAvatar);
      expect(avatar.attributes()).toMatchObject({
        src: user.avatarUrl,
        alt: user.name,
      });
      expect(avatar.props('entityName')).toBe(user.username);
    });
  });

  it('shows when the approval was made', () => {
    getAllApprovals().forEach((approval) => {
      const approvalBlock = findApproval(approval.user.username);
      const timeago = approvalBlock.findComponent(TimeAgoTooltip);
      expect(timeago.props('time')).toBe(approval.createdAt);
    });
  });

  it('renders comment body only for approvals with comment', () => {
    getAllApprovals().forEach((item) => {
      const commentBody = findApprovalComment(item.user.username);

      expect(commentBody.exists()).toBe(Boolean(item.comment));

      if (item.comment) {
        expect(commentBody.text()).toContain(item.comment);
      }
    });
  });

  it('shows correct status badge', () => {
    const variants = {
      APPROVED: { text: 'Approved', variant: 'success' },
      REJECTED: { text: 'Rejected', variant: 'danger' },
    };

    getAllApprovals().forEach((approval) => {
      const { text, variant } = variants[approval.status];
      const badge = findApproval(approval.user.username).findComponent(GlBadge);

      expect(badge.text()).toBe(text);
      expect(badge.props('variant')).toBe(variant);
    });
  });

  it('shows role tooltip on status badge', () => {
    approvalSummary.rules.forEach((rule) => {
      const role =
        rule.user?.name || rule.group?.name || ACCESS_LEVEL[rule.accessLevel?.stringValue]?.display;

      const statusLabels = { APPROVED: 'Approved', REJECTED: 'Rejected' };

      rule.approvals.forEach((approval) => {
        const badge = findApproval(approval.user.username).findComponent(GlBadge);

        expect(badge.attributes('title')).toBe(`${statusLabels[approval.status]} as ${role}`);
      });
    });
  });
});
