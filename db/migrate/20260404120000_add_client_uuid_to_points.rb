# frozen_string_literal: true

# client_uuid: opciono polje sa klijenta (UUID string) za idempotentan sync / bulk.
#
# Backward compatible: stare tačke ostaju sa client_uuid = NULL.
#
# PostgreSQL: u običnom UNIQUE (kolone) više redova sa NULL u client_uuid se NE smatra
# duplikatom (NULL ≠ NULL za svrhe jedinstvenosti). Ipak koristimo parcijalni indeks
# WHERE client_uuid IS NOT NULL da eksplicitno važi samo kad je UUID postavljen.
class AddClientUuidToPoints < ActiveRecord::Migration[8.0]
  def change
    add_column :points, :client_uuid, :string, null: true

    add_index :points,
              %i[hike_route_id client_uuid],
              unique: true,
              name: "index_points_on_hike_route_id_and_client_uuid_unique",
              where: "client_uuid IS NOT NULL"
  end
end
