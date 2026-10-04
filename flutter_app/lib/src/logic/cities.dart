/// A city of the Takvim. [off] is the difference from the base times, in minutes.
class City {
  const City(this.id, this.name, this.off);

  final String id;
  final String name;
  final int off;
}

/// Dallimet sipas Takvimit të BIK. Qytetet pa dallim përdorin kohët bazë.
const List<City> cities = [
  City('kosove', 'Kosovë', 0),
  City('decan', 'Deçan', 0),
  City('dragash', 'Dragash (Sharr)', 2),
  City('drenas', 'Drenas', 0),
  City('ferizaj', 'Ferizaj', -1),
  City('gjakove', 'Gjakovë', 0),
  City('gjilan', 'Gjilan', -1),
  City('istog', 'Istog', 0),
  City('kline', 'Klinë', 0),
  City('malisheve', 'Malishevë', 0),
  City('mitrovice', 'Mitrovicë', 0),
  City('peje', 'Pejë', 0),
  City('podujeve', 'Podujevë', -1),
  City('prishtine', 'Prishtinë', -1),
  City('prizren', 'Prizren', 0),
  City('rahovec', 'Rahovec', 0),
  City('skenderaj', 'Skënderaj', 0),
  City('suhareke', 'Suharekë', 0),
  City('vushtrri', 'Vushtrri', -1),
];

City cityById(String? id) => cities.firstWhere((c) => c.id == id, orElse: () => cities.first);
