import { getTimeago, newDate } from '~/lib/utils/datetime_utility';
import { __, sprintf } from '~/locale';

import { filterState } from '../constants';

export default {
  computed: {
    reference() {
      return `#${this.requirement?.workItemIid}`;
    },
    legacyReference() {
      return `REQ-${this.requirement?.iid}`;
    },
    titleHtml() {
      return this.requirement?.titleHtml;
    },
    descriptionHtml() {
      return this.requirement?.descriptionHtml;
    },
    isArchived() {
      return this.requirement?.state === filterState.archived;
    },
    author() {
      return this.requirement?.author;
    },
    createdAtFormatted() {
      if (!this.requirement?.createdAt) {
        return '';
      }

      return sprintf(__('created %{timeAgo}'), {
        timeAgo: getTimeago().format(newDate(this.requirement.createdAt)),
      });
    },
    updatedAtFormatted() {
      if (!this.requirement?.updatedAt) {
        return '';
      }

      return sprintf(__('updated %{timeAgo}'), {
        timeAgo: getTimeago().format(newDate(this.requirement.updatedAt)),
      });
    },
    testReport() {
      return this.requirement?.testReports.nodes[0];
    },
    canUpdate() {
      return this.requirement?.userPermissions.updateRequirement;
    },
    canArchive() {
      return this.requirement?.userPermissions.adminRequirement;
    },
  },
};
