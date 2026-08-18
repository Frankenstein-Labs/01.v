// Fixture located at ee/spec/frontend/fixtures/merge_trains.rb
import trainWithoutPermissions from 'test_fixtures/ee/graphql/merge_trains/active_merge_trains_guest.json';
import activeTrain from 'test_fixtures/ee/graphql/merge_trains/active_merge_trains.json';
import mergedTrain from 'test_fixtures/ee/graphql/merge_trains/completed_merge_trains.json';

// built with fixture data but manual pageInfo
// inserted for testing pagination and avoiding the need
// to create multiple cars on a train in fixtures
export const trainWithPagination = {
  data: {
    project: {
      id: 'gid://gitlab/Project/2',
      mergeTrains: {
        nodes: [
          {
            targetBranch: 'master',
            cars: {
              ...activeTrain.data.project.mergeTrains.nodes[0].cars,
              pageInfo: {
                hasNextPage: true,
                hasPreviousPage: false,
                startCursor: 'eyJpZCI6IjQifQ',
                endCursor: 'eyJpZCI6IjQifQ',
              },
            },
          },
        ],
      },
    },
  },
};

export const emptyTrain = {
  data: {
    project: {
      id: 'gid://gitlab/Project/20',
      mergeTrains: {
        nodes: [],
      },
    },
  },
};

export const deleteCarSuccess = {
  data: {
    mergeTrainsDeleteCar: {
      errors: [],
    },
  },
};

export const deleteCarFailure = {
  data: {
    mergeTrainsDeleteCar: {
      errors: ['New error'],
    },
  },
};

export { activeTrain, mergedTrain, trainWithoutPermissions };
