import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import ServiceLevelAgreement from 'ee_component/vue_shared/components/incidents/service_level_agreement.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import IncidentsList from '~/incidents/components/incidents_list.vue';
import getIncidents from '~/incidents/graphql/queries/get_incidents.query.graphql';
import getIncidentsCountByStatus from '~/incidents/graphql/queries/get_count_by_status.query.graphql';
import workItemTypesConfigurationQuery from '~/work_items/graphql/work_item_types_configuration.query.graphql';
import getIncidentStateQuery from 'ee/graphql_shared/queries/get_incident_state.query.graphql';
import mockIncidents from './mocks/incidents.json';

Vue.use(VueApollo);

const INCIDENT_TYPE_ID = 'gid://gitlab/WorkItems::Type/2';

const incidentNodes = mockIncidents.map((incident, index) => ({
  __typename: 'Issue',
  id: `gid://gitlab/Issue/${index + 1}`,
  title: null,
  createdAt: null,
  state: 'opened',
  severity: 'UNKNOWN',
  escalationStatus: null,
  statusPagePublishedIncident: null,
  slaDueAt: null,
  ...incident,
  labels: { __typename: 'LabelConnection', nodes: [] },
  assignees: { __typename: 'UserCoreConnection', nodes: [] },
}));

const incidentsResponse = {
  data: {
    project: {
      __typename: 'Project',
      id: 'gid://gitlab/Project/1',
      issues: {
        __typename: 'IssueConnection',
        nodes: incidentNodes,
        pageInfo: {
          __typename: 'PageInfo',
          hasNextPage: false,
          hasPreviousPage: false,
          startCursor: null,
          endCursor: null,
        },
      },
    },
  },
};

const incidentsCountResponse = {
  data: {
    project: {
      __typename: 'Project',
      id: 'gid://gitlab/Project/1',
      issueStatusCounts: {
        __typename: 'IssueStatusCountsType',
        all: 4,
        opened: 4,
        closed: 0,
      },
    },
  },
};

const workItemTypesResponse = {
  data: {
    namespace: {
      __typename: 'Namespace',
      id: 'gid://gitlab/Namespaces::ProjectNamespace/1',
      workItemTypes: {
        __typename: 'WorkItemTypeConnection',
        nodes: [
          {
            __typename: 'WorkItemType',
            id: INCIDENT_TYPE_ID,
            name: 'Incident',
            archived: false,
            enabled: true,
            canPromoteToObjective: false,
            canUserCreateItems: true,
            iconName: 'work-item-incident',
            isConfigurable: true,
            isFilterableBoardView: true,
            isFilterableListView: true,
            isGroupWorkItemType: false,
            isIncidentManagement: true,
            isServiceDesk: false,
            showProjectSelector: false,
            supportsMoveAction: true,
            supportsRoadmapView: false,
            useIssueView: true,
            visibleInSettings: true,
            widgetDefinitions: [],
          },
        ],
      },
    },
  },
};

const incidentStateResponse = {
  data: {
    project: {
      __typename: 'Project',
      id: 'gid://gitlab/Project/1',
      issue: {
        __typename: 'Issue',
        id: 'gid://gitlab/Issue/1',
        state: 'opened',
      },
    },
  },
};

const defaultProvide = {
  projectPath: '/project/path',
  newIssuePath: 'namespace/project/-/issues/new',
  incidentTemplateName: 'incident',
  incidentType: 'incident',
  issuePath: '/project/issues',
  publishedAvailable: true,
  emptyListSvgPath: '/assets/empty.svg',
  textQuery: '',
  authorUsernameQuery: '',
  assigneeUsernameQuery: '',
  slaFeatureAvailable: true,
  canCreateIncident: true,
};

describe('Incidents Service Level Agreement', () => {
  let wrapper;

  const findIncidentSlaHeader = () => wrapper.findByTestId('incident-management-sla');
  const findIncidentSLAs = () => wrapper.findAllComponents(ServiceLevelAgreement);

  async function mountComponent(provide = {}) {
    wrapper = mountExtended(IncidentsList, {
      apolloProvider: createMockApollo([
        [getIncidents, jest.fn().mockResolvedValue(incidentsResponse)],
        [getIncidentsCountByStatus, jest.fn().mockResolvedValue(incidentsCountResponse)],
        [workItemTypesConfigurationQuery, jest.fn().mockResolvedValue(workItemTypesResponse)],
        [getIncidentStateQuery, jest.fn().mockResolvedValue(incidentStateResponse)],
      ]),
      provide: {
        ...defaultProvide,
        ...provide,
      },
    });

    // The incidents and incidentsCount queries skip while incidentTypeId is
    // undefined, and incidentTypeId is a computed derived from the
    // workItemTypesConfiguration result.
    await waitForPromises(); // resolves workItemTypesConfiguration
    await nextTick(); // Vue recomputes incidentTypeId, un-skipping the incidents query
    await waitForPromises(); // resolves incidents + incidentsCount
  }

  describe('Incident SLA field', () => {
    it('displays the column when the feature is available', async () => {
      await mountComponent({ slaFeatureAvailable: true });

      expect(findIncidentSlaHeader().text()).toContain('Time to SLA');
    });

    it('does not display the column when the feature is not available', async () => {
      await mountComponent({ slaFeatureAvailable: false });

      expect(findIncidentSlaHeader().exists()).toBe(false);
    });

    it('renders an SLA for each incident with an SLA', async () => {
      await mountComponent({ slaFeatureAvailable: true });

      expect(findIncidentSLAs()).toHaveLength(2);
    });
  });
});
