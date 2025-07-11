# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# This script uses the TodoApp.Seeds.DataGenerator module to generate
# fresh data with relative dates. The same module is also used by the
# scheduled job to refresh data daily.

# Use the centralized data generator
TodoApp.Seeds.DataGenerator.seed_database()