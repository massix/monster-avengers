#include "monster_hunter_data.h"
#include "query.h"
#include "armor_up.h"
#include "helpers.h"

using namespace monster_avengers;

int main(int argc, char **argv) {
  std::setlocale(LC_ALL, "en_US.UTF-8");
  CHECK(2 <= argc);
  ArmorUp armor_up(argv[1]);
  if (argc < 4) {
    armor_up.ListSkills();
  } else {
    Query query;
    CHECK_SUCCESS(Query::ParseFile(argv[2], &query));
    armor_up.SearchAndLispOut(query, argv[3]);
  }
  return 0;
}
