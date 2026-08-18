import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { relayStylePagination } from '@apollo/client/utilities';
import { makeVar } from '@apollo/client/core';
import createDefaultClient from '~/lib/graphql';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_FORBIDDEN } from '~/lib/utils/http_status';
import * as Sentry from '~/sentry/sentry_browser_wrapper';

Vue.use(VueApollo);

let containerScanningForRegistry;

// Please see this comment for an explanation of what this does:
// https://gitlab.com/gitlab-org/gitlab/-/merge_requests/86408#note_942523549
export const cacheConfig = {
  typePolicies: {
    Group: {
      fields: {
        projects: relayStylePagination(['includeSubgroups', 'ids', 'search']),
        securityMetrics: {
          merge: true,
        },
      },
    },
    InstanceSecurityDashboard: {
      fields: {
        projects: relayStylePagination(['search']),
      },
    },
    Organization: {
      fields: {
        projects: relayStylePagination(['search']),
        securityMetrics: {
          merge: true,
        },
      },
    },
    Project: {
      fields: {
        containerScanningForRegistry: {
          read(_, { variables }) {
            if (!containerScanningForRegistry) {
              containerScanningForRegistry = makeVar({
                __typename: 'LocalContainerScanningForRegistry',
                isEnabled: false,
                isVisible: false,
              });

              axios
                .get(variables.securityConfigurationPath)
                .then(({ data }) => {
                  containerScanningForRegistry({
                    __typename: 'LocalContainerScanningForRegistry',
                    isEnabled: data.container_scanning_for_registry_enabled,
                    isVisible: true,
                  });
                })
                .catch((e) => {
                  if (e.response?.status === HTTP_STATUS_FORBIDDEN) {
                    return containerScanningForRegistry({
                      __typename: 'LocalContainerScanningForRegistry',
                      isEnabled: false,
                      isVisible: false,
                    });
                  }
                  return Sentry.captureException(e);
                });
            }

            return containerScanningForRegistry();
          },
        },
        securityMetrics: {
          merge: true,
        },
      },
    },
  },
};

export const defaultClient = createDefaultClient(
  {},
  {
    cacheConfig,
  },
);

export default new VueApollo({ defaultClient });
