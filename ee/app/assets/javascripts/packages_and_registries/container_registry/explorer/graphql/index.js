import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { makeVar } from '@apollo/client/core';
import createDefaultClient from '~/lib/graphql';
import { config } from '~/packages_and_registries/container_registry/explorer/graphql';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_FORBIDDEN } from '~/lib/utils/http_status';
import * as Sentry from '~/sentry/sentry_browser_wrapper';

Vue.use(VueApollo);

export const mergeVariables = (existing, incoming) => {
  if (!incoming) return existing;
  return incoming;
};

let containerScanningForRegistry;

export const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(
    {},
    {
      cacheConfig: {
        typePolicies: {
          ...config.cacheConfig.typePolicies,
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
            },
          },
        },
      },
    },
  ),
});
