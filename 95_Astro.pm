########################################################################################
#
# 95_Astro.pm
#
# Collection of various routines for astronomical data
# Prof. Dr. Peter A. Henning
#
# Equations from "Practical Astronomy with your Calculator" by Peter Duffett-Smith
# Program skeleton (with some errors) by Arnold Barmettler 
# http://lexikon.astronomie.info/java/sunmoon/
#
# Seasonal (temporal/roman) hour calculation is based on description on Wikipedia
# and was initially provided by Julian Pawlowski.
# https://de.wikipedia.org/wiki/Temporale_Stunden
# https://de.wikipedia.org/wiki/Tageszeit
#
# Seasonal hour naming is based on description about the day by "Nikolaus A. Bär"
# and was initially provided by Julian Pawlowski.
# http://www.nabkal.de/tag.html
#
# Estimation of the Phenological Season is based on data provided by "Deutscher Wetterdienst",
#  in particular data about durations of the year 2017.
#  It was initially provided by Julian Pawlowski.
# https://www.dwd.de/DE/klimaumwelt/klimaueberwachung/phaenologie/produkte/phaenouhr/phaenouhr.html
#
#  $Id: 95_Astro.pm 19405 2019-05-19 08:50:54Z phenning $
#
########################################################################################
#
#  This programm is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  The GNU General Public License can be found at
#  http://www.gnu.org/copyleft/gpl.html.
#  A copy is found in the textfile GPL.txt and important notices to the license
#  from the author is found in LICENSE.txt distributed with these scripts.
#
#  This script is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
########################################################################################

package FHEM::Astro;
use strict;
use warnings; 
use POSIX;

use GPUtils qw(GP_Import);
use Math::Trig;
use Time::HiRes qw(gettimeofday);
use Time::Local;
#use Data::Dumper;

my $DEG = pi/180.0;
my $RAD = 180./pi;

my $deltaT   = 65;  # Correction time in s

my %Astro;
my %Date;

our $VERSION = 1.6;

#-- These we may set on request
my %sets = (
    "update" => "noArg",
);

#-- These we may get on request
my %gets = (
    "json"    => undef,
    "text"    => undef,
    "version" => "noArg",
);

#-- These we may configure
my %attrs = (
    "altitude"    => undef,
    "disable"     => "1,0",
    "earlyfall"   => undef,
    "earlyspring" => undef,
    "horizon"     => undef,
    "interval"    => undef,
    "language"    => "EN,DE,ES,FR,IT,NL,PL",
    "latitude"    => undef,
    "longitude"   => undef,
    "recomputeAt" => "multiple-strict,MoonRise,MoonSet,MoonTransit,NewDay,SeasonalHr,SunRise,SunSet,SunTransit,AstroTwilightEvening,AstroTwilightMorning,CivilTwilightEvening,CivilTwilightMorning,CustomTwilightEvening,CustomTwilightMorning",
    "schedule"    => "multiple-strict,MoonPhaseS,MoonRise,MoonSet,MoonSign,MoonTransit,ObsDate,ObsIsDST,ObsMeteoSeason,ObsPhenoSeason,ObsSeason,ObsSeasonalHr,SunRise,SunSet,SunSign,SunTransit,AstroTwilightEvening,AstroTwilightMorning,CivilTwilightEvening,CivilTwilightMorning,NauticTwilightEvening,NauticTwilightMorning,CustomTwilightEvening,CustomTwilightMorning",
    "seasonalHrs" => undef,
);

my $json;
my $tt;

#-- Export variables to other programs
our %transtable = (
  EN => {
    "overview"          =>  "Summary",
    "name"              =>  "Name", 
    "time"              =>  "Time",
    "action"            =>  "Action",
    "type"              =>  "Type",
    "description"       =>  "Description",
    "profile"           =>  "Profile",
    #--
    "coord"             =>  "Coordinates",
    "position"          =>  "Position",
    "longitude"         =>  "Longitude",
    "latitude"          =>  "Latitude",
    "altitude"          =>  "Height m.a.s.l.",
    "lonecl"            =>  "Ecliptical longitude",
    "latecl"            =>  "Ecliptical latitude",
    "ra"                =>  "Right ascension",        
    "dec"               =>  "Declination",
    "az"                =>  "Azimuth",
    "alt"               =>  "Horizontal altitude",
    "age"               =>  "Age",
    "rise"              =>  "Rise",
    "set"               =>  "Set",
    "transit"           =>  "Transit",
    "distance"          =>  "Distance",
    "diameter"          =>  "Diameter",
    "toobs"             =>  "to observer",
    "toce"              =>  "to Earth center",
    "twilightcivil"     =>  "Civil twilight",
    "twilightnautic"    =>  "Nautical twilight",
    "twilightastro"     =>  "Astronomical twilight",
    "twilightcustom"    =>  "Custom twilight",
    "sign"              =>  "Zodiac sign",
    "dst"               =>  "daylight saving time",
    "leapyear"          =>  "leap year",
    "hoursofsunlight"   =>  "Hours of sunlight",
    "hoursofnight"      =>  "Hours of night",
    "hoursofvisibility" =>  "Visibility",
    #--
    "seasonalhour"      =>  "Seasonal Hour",
    "temporalhour"      =>  "Temporal Hour",
    #--
    "dayphase"          => "Daytime",
    "dusk"              => "Dusk",
    "earlyevening"      => "Early evening",
    "evening"           => "Evening",
    "lateevening"       => "Late evening",
    "earlynight"        => "Early night",
    "beforemidnight"    => "Before midnight",
    "midnight"          => "Midnight",
    "aftermidnight"     => "After midnight",
    "latenight"         => "Late night",
    "cockcrow"          => "Cock-crow",
    "firstmorninglight" => "First morning light",
    "dawn"              => "Dawn",
    "breakingdawn"      => "Breaking dawn",
    "earlymorning"      => "Early morning",
    "morning"           => "Morning",
    "earlyforenoon"     => "Early forenoon",
    "forenoon"          => "Forenoon",
    "lateforenoon"      => "Late forenoon",
    "noon"              => "Noon",
    "earlyafternoon"    => "Early afternoon",
    "afternoon"         => "Afternoon",
    "lateafternoon"     => "Late afternoon",
    "firstdusk"         => "First dusk",
    #--
    "today"             =>  "Today",
    "tomorrow"          =>  "Tomorrow",
    "weekday"           =>  "Day of Week",
    "date"              =>  "Date",
    "jdate"             =>  "Julian date",
    "dayofyear"         =>  "day of year",
    "days"              =>  "days",
    "daysremaining"     =>  "days remaining",
    "dayremaining"      =>  "day remaining",
    "timezone"          =>  "Time Zone",
    "lmst"              =>  "Local Sidereal Time",  
    #--
    "monday"    =>  ["Monday","Mon"],
    "tuesday"   =>  ["Tuesday","Tue"],
    "wednesday" =>  ["Wednesday","Wed"],
    "thursday"  =>  ["Thursday","Thu"],
    "friday"    =>  ["Friday","Fri"],
    "saturday"  =>  ["Saturday","Sat"],
    "sunday"    =>  ["Sunday","Sun"],
    #--
    "season"    => "Astronomical Season",
    "spring"    => "Spring",
    "summer"    => "Summer",
    "fall"      => "Fall",
    "winter"    => "Winter",
    #--
    "metseason" => "Meteorological Season",
    #--
    "phenseason"  => "Phenological Season",
    "earlyspring" => "Early Spring",
    "firstspring" => "First Spring",
    "fullspring"  => "Full Spring",
    "earlysummer" => "Early Summer",
    "midsummer"   => "Midsummer",
    "latesummer"  => "Late Summer",
    "earlyfall"   => "Early Fall",
    "fullfall"    => "Full Fall",
    "latefall"    => "Late Fall",
    #--
    "aries"     => "Ram",
    "taurus"    => "Bull",
    "gemini"    => "Twins",
    "cancer"    => "Crab",
    "leo"       => "Lion",
    "virgo"     => "Maiden",
    "libra"     => "Scales",
    "scorpio"   => "Scorpion",
    "sagittarius" => "Archer",
    "capricorn" => "Goat",
    "aquarius"  => "Water Bearer",
    "pisces"    => "Fish",
    #--
    "sun"         => "Sun",
    #--
    "moon"           => "Moon",
    "phase"          => "Phase",
    "newmoon"        => "New Moon",
    "waxingcrescent" => "Waxing Crescent",
    "firstquarter"   => "First Quarter",
    "waxingmoon"     => "Waxing Moon",
    "fullmoon"       => "Full Moon",
    "waningmoon"     => "Waning Moon",
    "lastquarter"    => "Last Quarter",
    "waningcrescent" => "Waning Crescent",
    #--
    "cpn"         => ["North",          "N"],
    "cpnne"       => ["North-Northeast","NNE"],
    "cpne"        => ["North-East",     "NE"],
    "cpene"       => ["East-Northeast", "ENE"],
    "cpe"         => ["East",           "E"],
    "cpese"       => ["East-Southeast", "ESE"],
    "cpse"        => ["Southeast",      "SE"],
    "cpsse"       => ["South-Southeast","SSE"],
    "cps"         => ["South",          "S"],
    "cpssw"       => ["South-Southwest","SSW"],
    "cpsw"        => ["Southwest",      "SW"],
    "cpwsw"       => ["West-Southwest", "WSW"],
    "cpw"         => ["West",           "W"],
    "cpwnw"       => ["West-Northwest", "WNW"],
    "cpnw"        => ["Northwest",      "NW"],
    "cpnnw"       => ["North-Northwest","NNW"],
  },

  DE => {
    "overview"          =>  "Zusammenfassung",
    "name"              =>  "Name", 
    "time"              =>  "Zeit",
    "action"            =>  "Aktion",
    "type"              =>  "Typ",
    "description"       =>  "Beschreibung",
    "profile"           =>  "Profil",
    #--
    "coord"             =>  "Koordinaten",
    "position"          =>  "Position",
    "longitude"         =>  "Länge",
    "latitude"          =>  "Breite",
    "altitude"          =>  "Höhe ü.M.",
    "lonecl"            =>  "Eklipt. Länge",
    "latecl"            =>  "Eklipt. Breite",
    "ra"                =>  "Rektaszension",        
    "dec"               =>  "Deklination",
    "az"                =>  "Azimut",
    "alt"               =>  "Horizontwinkel",
    "age"               =>  "Alter",
    "phase"             =>  "Phase",
    "rise"              =>  "Aufgang",
    "set"               =>  "Untergang",
    "transit"           =>  "Kulmination",
    "distance"          =>  "Entfernung",
    "diameter"          =>  "Durchmesser",
    "toobs"             =>  "z. Beobachter",
    "toce"              =>  "z. Erdmittelpunkt",
    "twilightcivil"     =>  "Bürgerliche Dämmerung",
    "twilightnautic"    =>  "Nautische Dämmerung",
    "twilightastro"     =>  "Astronomische Dämmerung",
    "twilightcustom"    =>  "Konfigurierte Dämmerung",
    "sign"              =>  "Tierkreiszeichen",
    "dst"               =>  "Sommerzeit",
    "leapyear"          =>  "Schaltjahr",
    "hoursofsunlight"   =>  "Tagesstunden",
    "hoursofnight"      =>  "Nachtstunden",
    "hoursofvisibility" =>  "Sichtbarkeit",
    #--
    "seasonalhour"      =>  "Saisonale Stunde",
    "temporalhour"      =>  "Temporale Stunde",
    #--
    "dayphase"          => "Tageszeit",
    "dusk"              => "Abenddämmerung",
    "earlyevening"      => "früher Abend",
    "evening"           => "Abend",
    "lateevening"       => "Später Abend",
    "earlynight"        => "Frühe Nacht",
    "beforemidnight"    => "Vor-Mitternacht",
    "midnight"          => "Mitternacht",
    "aftermidnight"     => "Nach-Mitternacht",
    "latenight"         => "Späte Nacht",
    "cockcrow"          => "Hahnenschrei",
    "firstmorninglight" => "Erstes Morgenlicht",
    "dawn"              => "Morgendämmerung",
    "breakingdawn"      => "Tagesanbruch",
    "earlymorning"      => "Früher Morgen",
    "morning"           => "Morgen",
    "earlyforenoon"     => "Früher Vormittag",
    "forenoon"          => "Vormittag",
    "lateforenoon"      => "Später Vormittag",
    "noon"              => "Mittag",
    "earlyafternoon"    => "Früher Nachmittag",
    "afternoon"         => "Nachmittag",
    "lateafternoon"     => "Später Nachmittag",
    "firstdusk"         => "Erste Dämmerung",
    #--
    "today"             =>  "Heute",
    "tomorrow"          =>  "Morgen",
    "weekday"           =>  "Wochentag",
    "date"              =>  "Datum",
    "jdate"             =>  "Julianisches Datum",
    "dayofyear"         =>  "Tag d. Jahres",
    "days"              =>  "Tage",
    "daysremaining"     =>  "Tage verbleibend",
    "dayremaining"      =>  "Tag verbleibend",
    "timezone"          =>  "Zeitzone",
    "lmst"              =>  "Lokale Sternzeit",  
    #--
    "monday"    =>  ["Montag","Mo"],
    "tuesday"   =>  ["Dienstag","Di"],
    "wednesday" =>  ["Mittwoch","Mi"],
    "thursday"  =>  ["Donnerstag","Do"],
    "friday"    =>  ["Freitag","Fr"],
    "saturday"  =>  ["Samstag","Sa"],
    "sunday"    =>  ["Sonntag","So"],
    #--
    "season"    => "Astronomische Jahreszeit",
    "spring"    => "Frühling",
    "summer"    => "Sommer",
    "fall"      => "Herbst",
    "winter"    => "Winter",
    #--
    "metseason" => "Meteorologische Jahreszeit",
    #--
    "phenseason"  => "Phänologische Jahreszeit",
    "earlyspring" => "Vorfrühling",
    "firstspring" => "Erstfrühling",
    "fullspring"  => "Vollfrühling",
    "earlysummer" => "Frühsommer",
    "midsummer"   => "Hochsommer",
    "latesummer"  => "Spätsommer",
    "earlyfall"   => "Frühherbst",
    "fullfall"    => "Vollherbst",,
    "latefall"    => "Spätherbst",
    #--
    "aries"     => "Widder",
    "taurus"    => "Stier",
    "gemini"    => "Zwillinge",
    "cancer"    => "Krebs",
    "leo"       => "Löwe",
    "virgo"     => "Jungfrau",
    "libra"     => "Waage",
    "scorpio"   => "Skorpion",
    "sagittarius" => "Schütze",
    "capricorn" => "Steinbock",
    "aquarius"  => "Wassermann",
    "pisces"    => "Fische",
    #--
    "sun"         => "Sonne",
    #--
    "moon"           => "Mond",
    "phase"          => "Phase",
    "newmoon"        => "Neumond",
    "waxingcrescent" => "Zunehmende Sichel",
    "firstquarter"   => "Erstes Viertel",
    "waxingmoon"     => "Zunehmender Mond",
    "fullmoon"       => "Vollmond",
    "waningmoon"     => "Abnehmender Mond",
    "lastquarter"    => "Letztes Viertel",
    "waningcrescent" => "Abnehmende Sichel",
    #--
    "cpn"         => ["Norden",       "N"],
    "cpnne"       => ["Nord-Nordost", "NNO"],
    "cpne"        => ["Nord-Ost",     "NO"],
    "cpene"       => ["Ost-Nordost",  "ONO"],
    "cpe"         => ["Ost",          "O"],
    "cpese"       => ["Ost-Südost",   "OSO"],
    "cpse"        => ["Südost",       "SO"],
    "cpsse"       => ["Süd-Südost",   "SSO"],
    "cps"         => ["Süd",          "S"],
    "cpssw"       => ["Süd-Südwest",  "SSW"],
    "cpsw"        => ["Südwest",      "SW"],
    "cpwsw"       => ["West-Südwest", "WSW"],
    "cpw"         => ["West",         "W"],
    "cpwnw"       => ["West-Nordwest","WNW"],
    "cpnw"        => ["Nordwest",     "NW"],
    "cpnnw"       => ["Nord-Nordwest","NNW"],
  },

  ES => {
    "overview"          =>  "Resumen",
    "name"              =>  "Nombre", 
    "time"              =>  "Tiempo",
    "action"            =>  "Acción",
    "type"              =>  "Tipo",
    "description"       =>  "Descripción",
    "profile"           =>  "Perfil",
    #--
    "coord"             =>  "Coordenadas",
    "position"          =>  "Posición",
    "longitude"         =>  "Longitud",
    "latitude"          =>  "Latitud",
    "altitude"          =>  "Altura sobre el mar",
    "lonecl"            =>  "Longitud eclíptica",
    "latecl"            =>  "Latitud eclíptica",
    "ra"                =>  "Ascensión recta",        
    "dec"               =>  "Declinación",
    "az"                =>  "Azimut",
    "alt"               =>  "Ángulo horizonte",
    "age"               =>  "Edad",
    "rise"              =>  "Salida",
    "set"               =>  "Puesta",
    "transit"           =>  "Culminación",
    "distance"          =>  "Distancia",
    "diameter"          =>  "Diámetro",
    "toobs"             =>  "al observar",
    "toce"              =>  "al centro de la tierra",
    "twilightcivil"     =>  "Crepúsculo civil",
    "twilightnautic"    =>  "Crepúsculo náutico",
    "twilightastro"     =>  "Crepúsculo astronómico",
    "twilightcustom"    =>  "Personalizado twilight",
    "sign"              =>  "Signo del zodiaco",
    "dst"               =>  "horario de verano",
    "leapyear"          =>  "año bisiesto",
    "hoursofsunlight"   =>  "Horas de luz solar",
    "hoursofnight"      =>  "Horas de la noche",
    "hoursofvisibility" =>  "Visibilidad",
    #--
    "seasonalhour"      =>  "Hora Estacional",
    "temporalhour"      =>  "Hora Temporal",
    #--
    "dayphase"          => "Durante el día",
    "dusk"              => "Oscuridad",
    "earlyevening"      => "Atardecer temprano",
    "evening"           => "Nocturno",
    "lateevening"       => "Tarde",
    "earlynight"        => "Madrugada",
    "beforemidnight"    => "Antes de medianoche",
    "midnight"          => "Medianoche",
    "aftermidnight"     => "Después de medianoche",
    "latenight"         => "Noche tardía",
    "cockcrow"          => "Canto al gallo",
    "firstmorninglight" => "Primera luz de la mañana",
    "dawn"              => "Amanecer",
    "breakingdawn"      => "Rotura amanecer",
    "earlymorning"      => "Temprano en la mañana",
    "morning"           => "Mañana",
    "earlyforenoon"     => "Temprano antes de mediodía",
    "forenoon"          => "Antes de mediodía",
    "lateforenoon"      => "Tarde antes de mediodía",
    "noon"              => "Mediodía",
    "earlyafternoon"    => "Temprano después de mediodía",
    "afternoon"         => "Después de mediodía",
    "lateafternoon"     => "Tarde después de mediodía",
    "firstdusk"         => "Temprano oscuridad",
    #--
    "today"             =>  "Hoy",
    "tomorrow"          =>  "Mañana",
    "weekday"           =>  "Dia de la semana",
    "date"              =>  "Fecha",
    "jdate"             =>  "Fecha de Julian",
    "dayofyear"         =>  "Día del año",
    "days"              =>  "Días",
    "daysremaining"     =>  "Días restantes",
    "dayremaining"      =>  "Día restante",
    "timezone"          =>  "Zona horaria",
    "lmst"              =>  "Hora sideral local",  
    #--
    "monday"    =>  ["Lunes","Lun"],
    "tuesday"   =>  ["Martes","Mar"],
    "wednesday" =>  ["Miércoles","Mié"],
    "thursday"  =>  ["Jueves","Jue"],
    "friday"    =>  ["Friday","Fri"],
    "saturday"  =>  ["Viernes","Vie"],
    "sunday"    =>  ["Domingo","Dom"],
    #--
    "season"    => "Temporada Astronomica",
    "spring"    => "Primavera",
    "summer"    => "Verano",
    "fall"      => "Otoño",
    "winter"    => "Invierno",
    #--
    "metseason" => "Temporada Meteorológica",
    #--
    "phenseason"  => "Temporada Fenologica",
    "earlyspring" => "Inicio de la primavera",
    "firstspring" => "Primera primavera",
    "fullspring"  => "Primavera completa",
    "earlysummer" => "Comienzo del verano",
    "midsummer"   => "Pleno verano",
    "latesummer"  => "El verano pasado",
    "earlyfall"   => "Inicio del otoño",
    "fullfall"    => "Otoño completo",
    "latefall"    => "Finales de otoño",
    #--
    "aries"     => "Aries",
    "taurus"    => "Tauro",
    "gemini"    => "Geminis",
    "cancer"    => "Cáncer",
    "leo"       => "León",
    "virgo"     => "Virgo",
    "libra"     => "Libra",
    "scorpio"   => "Escorpión",
    "sagittarius" => "Sagitario",
    "capricorn" => "Capricornio",
    "aquarius"  => "Acuario",
    "pisces"    => "Piscis",
    #--
    "sun"         => "Sol",
    #--
    "moon"           => "Luna",
    "phase"          => "Fase",
    "newmoon"        => "Luna nueva",
    "waxingcrescent" => "Luna creciente",
    "firstquarter"   => "Primer cuarto",
    "waxingmoon"     => "Luna creciente",
    "fullmoon"       => "Luna llena",
    "waningmoon"     => "Luna menguante",
    "lastquarter"    => "Último cuarto",
    "waningcrescent" => "Creciente menguante",
    #--
    "cpn"         => ["Norte",         "N"],
    "cpnne"       => ["Norte-Noreste", "NNE"],
    "cpne"        => ["Noreste",       "NE"],
    "cpene"       => ["Este-Noreste",  "ENE"],
    "cpe"         => ["Este",          "E"],
    "cpese"       => ["Este-Sureste",  "ESE"],
    "cpse"        => ["Sureste",       "SE"],
    "cpsse"       => ["Sur-Sureste",   "SSE"],
    "cps"         => ["Sur",           "S"],
    "cpssw"       => ["Sudoeste",      "SDO"],
    "cpsw"        => ["Sur-Oeste",     "SO"],
    "cpwsw"       => ["Oeste-Suroeste","OSO"],
    "cpw"         => ["Oeste",         "O"],
    "cpwnw"       => ["Oeste-Noroeste","ONO"],
    "cpnw"        => ["Noroeste",      "NO"],
    "cpnnw"       => ["Norte-Noroeste","NNE"],
  },

  FR => {
    "overview"          =>  "Résumé",
    "name"              =>  "Nom", 
    "time"              =>  "Temps",
    "action"            =>  "Action",
    "type"              =>  "Type",
    "description"       =>  "Description",
    "profile"           =>  "Profil",
    #--
    "coord"             =>  "Coordonnées",
    "position"          =>  "Position",
    "longitude"         =>  "Longitude",
    "latitude"          =>  "Latitude",
    "altitude"          =>  "Hauteur au dessus de la mer",
    "lonecl"            =>  "Longitude écliptique",
    "latecl"            =>  "Latitude écliptique",
    "ra"                =>  "Ascension droite",        
    "dec"               =>  "Déclinaison",
    "az"                =>  "Azimut",
    "alt"               =>  "Angle horizon",
    "age"               =>  "Âge",
    "rise"              =>  "Lever",
    "set"               =>  "Coucher",
    "transit"           =>  "Culmination",
    "distance"          =>  "Distance",
    "diameter"          =>  "Diamètre",
    "toobs"             =>  "à l'observateur",
    "toce"              =>  "au centre de la terre",
    "twilightcivil"     =>  "Crépuscule civil",
    "twilightnautic"    =>  "Crépuscule nautique",
    "twilightastro"     =>  "Crépuscule astronomique",
    "twilightcustom"    =>  "Personnalisé twilight",
    "sign"              =>  "Signe du zodiaque",
    "dst"               =>  "heure d'été",
    "leapyear"          =>  "année bissextile",
    "hoursofsunlight"   =>  "Heures de soleil",
    "hoursofnight"      =>  "Heures de la nuit",
    "hoursofvisibility" =>  "Visibilité",
    #--
    "seasonalhour"      =>  "Heure de Saison",
    "temporalhour"      =>  "Heure Temporelle",
    #--
    "dayphase"          => "Heure du jour",
    "dusk"              => "Crépuscule",
    "earlyevening"      => "Début de soirée",
    "evening"           => "Soir",
    "lateevening"       => "Fin de soirée",
    "earlynight"        => "Nuit tombante",
    "beforemidnight"    => "Avant minuit",
    "midnight"          => "Minuit",
    "aftermidnight"     => "Après minuit",
    "latenight"         => "Tard dans la nuit",
    "cockcrow"          => "Coq de bruyère",
    "firstmorninglight" => "Première lueur du matin",
    "dawn"              => "Poindre",
    "breakingdawn"      => "Aube naissante",
    "earlymorning"      => "Tôt le matin",
    "morning"           => "Matin",
    "earlyforenoon"     => "Matinée matinale",
    "forenoon"          => "Matinée",
    "lateforenoon"      => "Matinée tardive",
    "noon"              => "Midi",
    "earlyafternoon"    => "Début d'après-midi",
    "afternoon"         => "Après-midi",
    "lateafternoon"     => "Fin d'après-midi",
    "firstdusk"         => "Premier crépuscule",
    #--
    "today"             =>  "Aujourd'hui",
    "tomorrow"          =>  "Demain",
    "weekday"           =>  "Jour de la semaine",
    "date"              =>  "Date",
    "jdate"             =>  "Date de Julien",
    "dayofyear"         =>  "jour de l'année",
    "days"              =>  "jours",
    "daysremaining"     =>  "jours restant",
    "dayremaining"      =>  "jour restant",
    "timezone"          =>  "Fuseau horaire",
    "lmst"              =>  "Heure sidérale locale",  
    #--
    "monday"    =>  ["Lundi","Lun"],
    "tuesday"   =>  ["Mardi","Mar"],
    "wednesday" =>  ["Mercredi","Mer"],
    "thursday"  =>  ["Jeudi","Jeu"],
    "friday"    =>  ["Vendredi","Ven"],
    "saturday"  =>  ["Samedi","Sam"],
    "sunday"    =>  ["Dimanche","Dim"],
    #--
    "season"    => "Saison Astronomique",
    "spring"    => "Printemps",
    "summer"    => "Été",
    "fall"      => "Automne",
    "winter"    => "Hiver",
    #--
    "metseason" => "Saison Météorologique",
    #--
    "phenseason"  => "Saison Phénologique",
    "earlyspring" => "Avant du printemps",
    "firstspring" => "Début du printemps",
    "fullspring"  => "Printemps",
    "earlysummer" => "Avant de l'été",
    "midsummer"   => "Milieu de l'été",
    "latesummer"  => "Fin de l'été",
    "earlyfall"   => "Avant de l'automne",
    "fullfall"    => "Automne",
    "latefall"    => "Fin de l'automne",
    #--
    "aries"     => "bélier",
    "taurus"    => "Taureau",
    "gemini"    => "Gémeaux",
    "cancer"    => "Cancer",
    "leo"       => "Lion",
    "virgo"     => "Jeune fille",
    "libra"     => "Balance",
    "scorpio"   => "Scorpion",
    "sagittarius" => "Sagittaire",
    "capricorn" => "Capricorne",
    "aquarius"  => "Verseau",
    "pisces"    => "Poissons",
    #--
    "sun"         => "Soleil",
    #--
    "moon"           => "Lune",
    "phase"          => "Phase",
    "newmoon"        => "Nouvelle lune",
    "waxingcrescent" => "Croissant croissant",
    "firstquarter"   => "Premier quart",
    "waxingmoon"     => "Lune croissante",
    "fullmoon"       => "Pleine lune",
    "waningmoon"     => "Lune décroissante",
    "lastquarter"    => "Le dernier quart",
    "waningcrescent" => "Croissant décroissant",
    #--
    "cpn"         => ["Nord",            "N"],
    "cpnne"       => ["Nord-Nord-Est",   "NNE"],
    "cpne"        => ["Nord-Est",        "NE"],
    "cpene"       => ["Est-Nord-Est",    "ENE"],
    "cpe"         => ["Est",             "E"],
    "cpese"       => ["Est-Sud-Est",     "ESE"],
    "cpse"        => ["Sud-Est",         "SE"],
    "cpsse"       => ["Sud-Sud-Est",     "SSE"],
    "cps"         => ["Sud",             "S"],
    "cpssw"       => ["Sud-Sud-Ouest",   "SSW"],
    "cpsw"        => ["Sud-Ouest",       "SW"],
    "cpwsw"       => ["Ouest-Sud-Ouest", "OSO"],
    "cpw"         => ["Ouest",           "O"],
    "cpwnw"       => ["Ouest-Nord-Ouest","ONO"],
    "cpnw"        => ["Nord-Ouest",      "NO"],
    "cpnnw"       => ["Nord-Nord-Ouest", "NNO"],
  },

  IT => {
    "overview"          =>  "Sommario",
    "name"              =>  "Nome", 
    "time"              =>  "Tempo",
    "action"            =>  "Azione",
    "type"              =>  "Genere",
    "description"       =>  "Descrizione",
    "profile"           =>  "Profilo",
    #--
    "coord"             =>  "Coordinate",
    "position"          =>  "Posizione",
    "longitude"         =>  "Longitudine",
    "latitude"          =>  "Latitudine",
    "altitude"          =>  "Altezza sopra il mare",
    "lonecl"            =>  "Longitudine ellittica",
    "latecl"            =>  "Latitudine eclittica",
    "ra"                =>  "Giusta ascensione",        
    "dec"               =>  "Declinazione",
    "az"                =>  "Azimut",
    "alt"               =>  "Angolo di orizzonte",
    "age"               =>  "Età",
    "rise"              =>  "Crescente",
    "set"               =>  "Affondamento",
    "transit"           =>  "Culmine",
    "distance"          =>  "Distanza",
    "diameter"          =>  "Diametro",
    "toobs"             =>  "verso l'osservatore",
    "toce"              =>  "verso centro della terra",
    "twilightcivil"     =>  "Crepuscolo civile",
    "twilightnautic"    =>  "Crepuscolo nautico",
    "twilightastro"     =>  "Crepuscolo astronomico",
    "twilightcustom"    =>  "Crepuscolo personalizzato",
    "sign"              =>  "Segno zodiacale",
    "dst"               =>  "ora legale",
    "leapyear"          =>  "anno bisestile",
    "hoursofsunlight"   =>  "Ore di luce solare",
    "hoursofnight"      =>  "Ore della notte",
    "hoursofvisibility" =>  "Visibilità",
    #--
    "seasonalhour"      =>  "Ora di Stagione",
    "temporalhour"      =>  "Ora Temporale",
    #--
    "dayphase"          => "Tempo di giorno",
    "dusk"              => "Crepuscolo",
    "earlyevening"      => "Sera presto",
    "evening"           => "Serata",
    "lateevening"       => "Tarda serata",
    "earlynight"        => "Notte presto",
    "beforemidnight"    => "Prima mezzanotte",
    "midnight"          => "Mezzanotte",
    "aftermidnight"     => "Dopo mezzanotte",
    "latenight"         => "Tarda notte",
    "cockcrow"          => "Gallo corvo",
    "firstmorninglight" => "Prima luce del mattino",
    "dawn"              => "Alba",
    "breakingdawn"      => "Dopo l'alba",
    "earlymorning"      => "Mattina presto",
    "morning"           => "Mattina",
    "earlyforenoon"     => "Prima mattinata",
    "forenoon"          => "Mattinata",
    "lateforenoon"      => "Tarda mattinata",
    "noon"              => "Mezzogiorno",
    "earlyafternoon"    => "Primo pomeriggio",
    "afternoon"         => "Pomeriggio",
    "lateafternoon"     => "Tardo pomeriggio",
    "firstdusk"         => "Primo crepuscolo",
    #--
    "today"             =>  "Oggi",
    "tomorrow"          =>  "Domani",
    "weekday"           =>  "Giorno della settimana",
    "date"              =>  "Data",
    "jdate"             =>  "Data giuliana",
    "dayofyear"         =>  "giorno dell'anno",
    "days"              =>  "giorni",
    "daysremaining"     =>  "giorni rimanenti",
    "dayremaining"      =>  "giorno rimanente",
    "timezone"          =>  "Fuso orario",
    "lmst"              =>  "Tempo siderale locale",  
    #--
    "monday"    =>  ["Lunedi","Lun"],
    "tuesday"   =>  ["Martedì","Mar"],
    "wednesday" =>  ["Mercoledì","Mer"],
    "thursday"  =>  ["Giovedi","Gio"],
    "friday"    =>  ["Venerdì","Ven"],
    "saturday"  =>  ["Sabato","Sab"],
    "sunday"    =>  ["Domenica","Dom"],
    #--
    "season"    => "Stagione Astronomica",
    "spring"    => "Stagione primaverile",
    "summer"    => "Estate",
    "fall"      => "Autunno",
    "winter"    => "Inverno",
    #--
    "metseason" => "Stagione Meteorologica",
    #--
    "phenseason"  => "Stagione Fenologica",
    "earlyspring" => "Inizio primavera",
    "firstspring" => "Prima primavera",
    "fullspring"  => "Piena primavera",
    "earlysummer" => "Inizio estate",
    "midsummer"   => "Mezza estate",
    "latesummer"  => "Estate inoltrata",
    "earlyfall"   => "Inizio autunno",
    "fullfall"    => "Piena caduta",
    "latefall"    => "Tardo autunno",
    #--
    "aries"     => "Ariete",
    "taurus"    => "Toro",
    "gemini"    => "Gemelli",
    "cancer"    => "Cancro",
    "leo"       => "Leone",
    "virgo"     => "Vergine",
    "libra"     => "Libra",
    "scorpio"   => "Scorpione",
    "sagittarius" => "Arciere",
    "capricorn" => "Capricorno",
    "aquarius"  => "Acquario",
    "pisces"    => "Pesci",
    #--
    "sun"         => "Sole",
    #--
    "moon"           => "Luna",
    "phase"          => "Fase",
    "newmoon"        => "Nuova luna",
    "waxingcrescent" => "Luna crescente",
    "firstquarter"   => "Primo quarto",
    "waxingmoon"     => "Luna crescente",
    "fullmoon"       => "Luna piena",
    "waningmoon"     => "Luna calante",
    "lastquarter"    => "Ultimo quarto",
    "waningcrescent" => "Pericolo crescente",
    #--
    "cpn"         => ["Nord",            "N"],
    "cpnne"       => ["Nord-Nord-Est",   "NNE"],
    "cpne"        => ["Nord-Est",        "NE"],
    "cpene"       => ["Est-Nord-Est",    "ENE"],
    "cpe"         => ["Est",             "E"],
    "cpese"       => ["Est-Sud-Est",     "ESE"],
    "cpse"        => ["Sud-Est",         "SE"],
    "cpsse"       => ["Sud-Sud-Est",     "SSE"],
    "cps"         => ["Sud",             "S"],
    "cpssw"       => ["Sud-Sud-Ovest",   "SSO"],
    "cpsw"        => ["Sud-Ovest",       "SO"],
    "cpwsw"       => ["Ovest-Sud-Ovest", "OSO"],
    "cpw"         => ["Ovest",           "O"],
    "cpwnw"       => ["Ovest-Nord-Ovest","ONO"],
    "cpnw"        => ["Nord-Ovest",      "NO"],
    "cpnnw"       => ["Nord-Nord-Ovest", "NNO"],
  },

  NL => {
    "overview"          =>  "Samenvatting",
    "name"              =>  "Naam", 
    "time"              =>  "Tijd",
    "action"            =>  "Actie",
    "type"              =>  "Type",
    "description"       =>  "Omschrijving",
    "profile"           =>  "Profiel",
    #--
    "coord"             =>  "Coördinaten",
    "position"          =>  "Positie",
    "longitude"         =>  "Lengtegraad",
    "latitude"          =>  "Breedtegraad",
    "altitude"          =>  "Hoogte b. Zee",
    "lonecl"            =>  "Eclipticale Lengtegraad",
    "latecl"            =>  "Eclipticale Breedtegraad",
    "ra"                =>  "Juiste klimming",        
    "dec"               =>  "Declinatie",
    "az"                =>  "Azimuth",
    "alt"               =>  "Horizon Angle",
    "age"               =>  "Leeftijd",
    "rise"              =>  "Opkomst",
    "set"               =>  "Ondergang",
    "transit"           =>  "Culminatie",
    "distance"          =>  "Afstand",
    "diameter"          =>  "Diameter",
    "toobs"             =>  "voor de Waarnemer",
    "toce"              =>  "naar het Middelpunt van de Aarde",
    "twilightcivil"     =>  "Burgerlijke Schemering",
    "twilightnautic"    =>  "Nautische Schemering",
    "twilightastro"     =>  "Astronomische Schemering",
    "twilightcustom"    =>  "Aangepaste Schemering",
    "sign"              =>  "Sterrenbeeld",
    "dst"               =>  "Zomertijd",
    "leapyear"          =>  "Schrikkeljaar",
    "hoursofsunlight"   =>  "Dagen Uur",
    "hoursofnight"      =>  "Uren van de Nacht",
    "hoursofvisibility" =>  "Zichtbaarheid",
    #--
    "seasonalhour"      =>  "Seizoensgebonden Uur",
    "temporalhour"      =>  "Tijdelijk Uur",
    #--
    "dayphase"          => "Dagtijd",
    "dusk"              => "Schemer",
    "earlyevening"      => "Vroege Avond",
    "evening"           => "Avond",
    "lateevening"       => "Late Avond",
    "earlynight"        => "Vroege Nacht",
    "beforemidnight"    => "Voor Middernacht",
    "midnight"          => "Middernacht",
    "aftermidnight"     => "Na Middernacht",
    "latenight"         => "Late Nacht",
    "cockcrow"          => "Hanegekraai",
    "firstmorninglight" => "Eerste Ochtendlicht",
    "dawn"              => "Dageraad",
    "breakingdawn"      => "Ochtendgloren",
    "earlymorning"      => "Vroege Ochtend",
    "morning"           => "Ochtend",
    "earlyforenoon"     => "Vroeg in de Voormiddag",
    "forenoon"          => "Voormiddag",
    "lateforenoon"      => "Late Voormiddag",
    "noon"              => "Middag",
    "earlyafternoon"    => "Vroege Namiddag",
    "afternoon"         => "Namiddag",
    "lateafternoon"     => "Late Namiddag",
    "firstdusk"         => "Eerste Schemering",
    #--
    "today"             =>  "Vandaag",
    "tomorrow"          =>  "Morgen",
    "weekday"           =>  "Dag van de Week",
    "date"              =>  "Datum",
    "jdate"             =>  "Juliaanse Datum",
    "dayofyear"         =>  "Dag van het Jaar",
    "days"              =>  "Dagen",
    "daysremaining"     =>  "resterende Dagen",
    "dayremaining"      =>  "resterende Dag",
    "timezone"          =>  "Tijdzone",
    "lmst"              =>  "Lokale Sterrentijd",  
    #--
    "monday"    =>  ["Maandag","Maa"],
    "tuesday"   =>  ["Dinsdag","Din"],
    "wednesday" =>  ["Woensdag","Woe"],
    "thursday"  =>  ["Donderdag","Don"],
    "friday"    =>  ["Vrijdag","Vri"],
    "saturday"  =>  ["Zaterdag","Zat"],
    "sunday"    =>  ["Zondag","Zon"],
    #--
    "season"    => "Astronomisch Seizoen",
    "spring"    => "De lente",
    "summer"    => "Zomer",
    "fall"      => "Herfst",
    "winter"    => "Winter",
    #--
    "metseason" => "Meteorologisch Seizoen",
    #--
    "phenseason"  => "Fenologisch Seizoen",
    "earlyspring" => "Vroeg Voorjaar",
    "firstspring" => "Eerste Voorjaar",
    "fullspring"  => "Voorjaar",
    "earlysummer" => "Vroeg Zomer",
    "midsummer"   => "Zomer",
    "latesummer"  => "Laat Zomer",
    "earlyfall"   => "Vroeg Herfst",
    "fullfall"    => "Herfst",
    "latefall"    => "Laat Herfst",
    #--
    "aries"     => "Ram",
    "taurus"    => "Stier",
    "gemini"    => "Tweelingen",
    "cancer"    => "Kanker",
    "leo"       => "Leeuw",
    "virgo"     => "Maagd",
    "libra"     => "Weegschaal",
    "scorpio"   => "Schorpioen",
    "sagittarius" => "Boogschutter",
    "capricorn" => "Steenbok",
    "aquarius"  => "Waterman",
    "pisces"    => "Vis",
    #--
    "sun"         => "Zon",
    #--
    "moon"           => "Maan",
    "phase"          => "Fase",
    "newmoon"        => "Nieuwe Maan",
    "waxingcrescent" => "Wassende halve Maan",
    "firstquarter"   => "Eerste Kwartier",
    "waxingmoon"     => "Wassende Maan",
    "fullmoon"       => "Volle Maan",
    "waningmoon"     => "Afnemende Maan",
    "lastquarter"    => "Het laatste Kwartier",
    "waningcrescent" => "Afnemende halve Maan",
    #--
    "cpn"         => ["Noorden",          "N"],
    "cpnne"       => ["Noord-Noordoosten","NNO"],
    "cpne"        => ["Noordoosten",      "NO"],
    "cpene"       => ["Oost-Noordoost",   "ONO"],
    "cpe"         => ["Oosten",           "O"],
    "cpese"       => ["Oost-Zuidoost",    "OZO"],
    "cpse"        => ["Zuidoosten",       "ZO"],
    "cpsse"       => ["Zuid-Zuidoost",    "ZZO"],
    "cps"         => ["Zuiden",           "Z"],
    "cpssw"       => ["Zuid-Zuidwest",    "ZZW"],
    "cpsw"        => ["Zuidwest",         "ZW"],
    "cpwsw"       => ["West-Zuidwest",    "WZW"],
    "cpw"         => ["West",             "W"],
    "cpwnw"       => ["West-Noord-West",  "WNW"],
    "cpnw"        => ["Noord-West",       "NW"],
    "cpnnw"       => ["Noord-Noord-West", "NNW"],
  },

  PL => {
    "overview"          =>  "Streszczenie",
    "name"              =>  "Imię", 
    "time"              =>  "Czas",
    "action"            =>  "Akcja",
    "type"              =>  "Rodzaj",
    "description"       =>  "Opis",
    "profile"           =>  "Profil",
    #--
    "coord"             =>  "Współrzędne",
    "position"          =>  "Pozycja",
    "longitude"         =>  "Długość",
    "latitude"          =>  "Szerokość",
    "altitude"          =>  "Wysokość nad morzem",
    "lonecl"            =>  "Długość ekliptyczna",
    "latecl"            =>  "Szerokość ekliptyczna",
    "ra"                =>  "Rektascencja",        
    "dec"               =>  "Deklinacja",
    "az"                =>  "Azymut",
    "alt"               =>  "Kąt horyzont",
    "age"               =>  "Wiek",
    "rise"              =>  "Wschód",
    "set"               =>  "Zachód",
    "transit"           =>  "Kulminacja",
    "distance"          =>  "Dystans",
    "diameter"          =>  "Średnica",
    "toobs"             =>  "w kierunku obserwatora",
    "toce"              =>  "w kierunku środka ziemi",
    "twilightcivil"     =>  "Zmierzch cywilny",
    "twilightnautic"    =>  "Zmierzch morski",
    "twilightastro"     =>  "Brzask astronomiczny",
    "twilightcustom"    =>  "Niestandardowy zmierzch",
    "sign"              =>  "Znak zodiaku",
    "dst"               =>  "Czas letni",
    "leapyear"          =>  "rok przestępny",
    "hoursofsunlight"   =>  "Godziny światła słonecznego",
    "hoursofnight"      =>  "Godziny nocy",
    "hoursofvisibility" =>  "Widoczność",
    #--
    "seasonalhour"      =>  "Godzina Sezonowa",
    "temporalhour"      =>  "Czasowa Godzina",
    #--
    "dayphase"          => "Pora dnia",
    "dusk"              => "Zmierzch",
    "earlyevening"      => "Wczesnym wieczorem",
    "evening"           => "Wieczór",
    "lateevening"       => "Późny wieczór",
    "earlynight"        => "Wczesna noc",
    "beforemidnight"    => "Przed północą",
    "midnight"          => "Północ",
    "aftermidnight"     => "Po północy",
    "latenight"         => "Późna noc",
    "cockcrow"          => "Pianie koguta",
    "firstmorninglight" => "Pierwsze światło poranne",
    "dawn"              => "świt",
    "breakingdawn"      => "łamanie świtu",
    "earlymorning"      => "Wcześnie rano",
    "morning"           => "Ranek",
    "earlyforenoon"     => "Wczesne przedpołudnie",
    "forenoon"          => "Przedpołudnie",
    "lateforenoon"      => "Późne przedpołudnie",
    "noon"              => "Południe",
    "earlyafternoon"    => "Wczesne popołudnie",
    "afternoon"         => "Popołudnie",
    "lateafternoon"     => "Późne popołudnie",
    "firstdusk"         => "Pierwszy zmierzch",
    #--
    "today"             =>  "Dzisiaj",
    "tomorrow"          =>  "Jutro",
    "weekday"           =>  "Dzień tygodnia",
    "date"              =>  "Data",
    "jdate"             =>  "Juliańska data",
    "dayofyear"         =>  "dzień roku",
    "days"              =>  "dni",
    "daysremaining"     =>  "pozostało dni",
    "dayremaining"      =>  "pozostały dzień",
    "timezone"          =>  "Strefa czasowa",
    "lmst"              =>  "Lokalny czas gwiazdowy",  
    #--
    "monday"    =>  ["Poniedziałek","Pon"],
    "tuesday"   =>  ["Wtorek","Wto"],
    "wednesday" =>  ["środa","śro"],
    "thursday"  =>  ["Czwartek","Czw"],
    "friday"    =>  ["Piątek","Pią"],
    "saturday"  =>  ["Sobota","Sob"],
    "sunday"    =>  ["Niedziela","Nie"],
    #--
    "season"    => "Sezon Astronomiczny",
    "spring"    => "Wiosna",
    "summer"    => "Lato",
    "fall"      => "Jesień",
    "winter"    => "Zima",
    #--
    "metseason" => "Sezon Meteorologiczny",
    #--
    "phenseason"  => "Sezon Fenologiczny",
    "earlyspring" => "Wczesna wiosna",
    "firstspring" => "Pierwsza wiosna",
    "fullspring"  => "Pełna wiosna",
    "earlysummer" => "Wczesne lato",
    "midsummer"   => "Połowa lata",
    "latesummer"  => "Późne lato",
    "earlyfall"   => "Wczesna jesień",
    "fullfall"    => "Pełna jesień",
    "latefall"    => "Późną jesienią",
    #--
    "aries"     => "Baran",
    "taurus"    => "Byk",
    "gemini"    => "Bliźnięta",
    "cancer"    => "Rak",
    "leo"       => "Lew",
    "virgo"     => "Panna",
    "libra"     => "Libra",
    "scorpio"   => "Skorpion",
    "sagittarius" => "Strzelec",
    "capricorn" => "Koziorożec",
    "aquarius"  => "Wodnik",
    "pisces"    => "Ryby",
    #--
    "sun"         => "Słońce",
    #--
    "moon"           => "Księżyc",
    "phase"          => "Faza",
    "newmoon"        => "Nów",
    "waxingcrescent" => "Półksiężyc woskowy",
    "firstquarter"   => "Pierwszym kwartale",
    "waxingmoon"     => "Księżyc przybywający",
    "fullmoon"       => "Pełnia księżyca",
    "waningmoon"     => "Zmniejszający się księżyc",
    "lastquarter"    => "Ostatni kwartał",
    "waningcrescent" => "Zwiększający się księżyc",
    #--
    "cpn"         => ["Północ",                      "N"],
    "cpnne"       => ["Północny-Północny-Wschód",    "NNE"],
    "cpne"        => ["Północny-Wschód",             "NE"],
    "cpene"       => ["Wschód-Północny-Wschód",      "ENE"],
    "cpe"         => ["Wschód",                      "E"],
    "cpese"       => ["Wschód-Południowy-Wschód",    "ESE"],
    "cpse"        => ["Południowy-Południowy-Wschód","SE"],
    "cpsse"       => ["Południowy-Wschód",           "SSE"],
    "cps"         => ["Południe",                    "S"],
    "cpssw"       => ["Południowo-Południowy-Zachód","SSW"],
    "cpsw"        => ["Południowy-Zachód",           "SW"],
    "cpwsw"       => ["Zachód-Południowy-Zachód",    "WSW"],
    "cpw"         => ["Zachód",                      "W"],
    "cpwnw"       => ["Zachód-Północny-Zachód",      "WNW"],
    "cpnw"        => ["Północny-Zachód",             "NW"],
    "cpnnw"       => ["Północno-Północny-Zachód",    "NNW"],
  } );

our @zodiac = ("aries","taurus","gemini","cancer","leo","virgo",
    "libra","scorpio","sagittarius","capricorn","aquarius","pisces");

our @phases = ("newmoon","waxingcrescent", "firstquarter", "waxingmoon", 
    "fullmoon", "waningmoon", "lastquarter", "waningcrescent");

our @dayphases = (
    #-- night
    "dusk",
    "earlyevening",
    "evening",
    "lateevening",
    "earlynight",
    "beforemidnight",
    "midnight",
    "aftermidnight",
    "latenight",
    "cockcrow",
    "firstmorninglight",
    "dawn",
    #-- day
    "breakingdawn",
    "earlymorning",
    "morning",
    "earlyforenoon",
    "forenoon",
    "lateforenoon",
    "noon",
    "earlyafternoon",
    "afternoon",
    "afternoon",
    "lateafternoon",
    "firstdusk",
    );

my %roman = (
    1       => 'I',
    5       => 'V',
    10      => 'X',
    50      => 'L',
    100     => 'C',
    500     => 'D',
    1000    => 'M',
    5000    => '(V)',
    10000   => '(X)',
    50000   => '(L)',
    100000  => '(C)',
    500000  => '(D)',
    1000000 => '(M)',
);

our @seasons = (
    "winter","spring","summer","fall");

our %seasonn = (
    "spring" => [80,172],       #21./22.3. - 20.6.
    "summer" => [173,265],      #21.06. bis 21./22.09.
    "fall"   => [266,353],      #22./23.09. bis 20./21.12.
    "winter" => [354,79]        
    );

our %seasonmn = (
    "spring" => [3,5],          #01.03. - 31.5.
    "summer" => [6,8],          #01.06. - 31.8.
    "fall"   => [9,11],         #01.09. - 30.11.
    "winter" => [12,2],         #01.12. - 28./29.2.
    );

our @seasonsp = (
    "winter",
    "earlyspring","firstspring","fullspring",
    "earlysummer","midsummer","latesummer",
    "earlyfall","fullfall","latefall");

our %seasonppos = (
    earlyspring => [37.136633,-8.817837], #South-West Portugal
    earlyfall => [60.161880,24.937267],   #South Finland / Helsinki
    );

our @compasspoint = (
    "cpn","cpnne","cpne","cpene",
    "cpe","cpese","cpse","cpsse",
    "cps","cpssw","cpsw","cpwsw",
    "cpw","cpwnw","cpnw","cpnnw");

#-- Run before package compilation
BEGIN {

    # Import from main context
    GP_Import(
        qw(
          attr
          AttrVal
          data
          Debug
          defs
          deviceEvents
          FmtDateTime
          FW_pO
          FW_RET
          FW_RETTYPE
          FW_webArgs
          GetType
          init_done
          InternalTimer
          IsDisabled
          Log
          Log3
          maxNum
          minNum
          modules
          readingFnAttributes
          readingsBeginUpdate
          readingsBulkUpdateIfChanged
          readingsEndUpdate
          readingsSingleUpdate
          RemoveInternalTimer
          time_str2num
          toJSON
          )
    );
}

#-- Export to main context with different name
_Export(
    qw(
      Get
      Initialize
      )
);

_LoadOptionalPackages();

sub SunRise($$$$$$$$);
sub MoonRise($$$$$$$);
sub SetTime(;$$);
sub Compute($;$$);

########################################################################################################
#
# Initialize 
# 
# Parameter hash = hash of device addressed 
#
########################################################################################################

sub Initialize ($) {
  my ($hash) = @_;
		
  $hash->{DefFn}       = "FHEM::Astro::Define";
  $hash->{SetFn}       = "FHEM::Astro::Set";  
  $hash->{GetFn}       = "FHEM::Astro::Get";
  $hash->{UndefFn}     = "FHEM::Astro::Undef";   
  $hash->{AttrFn}      = "FHEM::Astro::Attr";    
  $hash->{NotifyFn}    = "FHEM::Astro::Notify";
  $hash->{AttrList}    = join (" ", map {
                                    defined($attrs{$_}) ? "$_:$attrs{$_}" : $_
                                  } sort keys %attrs
                         )
                         ." "
                         .$readingFnAttributes;

  $hash->{parseParams} = 1;

  $data{FWEXT}{"/Astro_moonwidget"}{FUNC} = "FHEM::Astro::Moonwidget";
  $data{FWEXT}{"/Astro_moonwidget"}{FORKABLE} = 0;		
	
  return undef;
}

########################################################################################################
#
# Define - Implements DefFn function
# 
# Parameter hash = hash of device addressed, def = definition string
#
########################################################################################################

sub Define ($@) {
 my ($hash,$a,$h) = @_;
 my $name = shift @$a;
 my $type = shift @$a;

 $hash->{VERSION} = $VERSION;
 $hash->{NOTIFYDEV} = "global";
 $hash->{INTERVAL} = 3600;
 readingsSingleUpdate( $hash, "state", "Initialized", $init_done ); 
 
 $modules{Astro}{defptr}{$name} = $hash;

 # for the very first definition, set some default attributes
 if ( $init_done && !defined( $hash->{OLDDEF} ) ) {
   $attr{$name}{icon}        = 'telescope';
   $attr{$name}{recomputeAt} = 'NewDay,SeasonalHr';
   $attr{$name}{stateFormat} = 'ObsDaytime';
 }

 return undef;
}

########################################################################################################
#
# Undef - Implements Undef function
# 
# Parameter hash = hash of device addressed, def = definition string
#
########################################################################################################

sub Undef ($$) {
  my ($hash,$arg) = @_;
  
  RemoveInternalTimer($hash);
  
  return undef;
}

########################################################################################################
#
# Notify - Implements Notify function
# 
# Parameter hash = hash of device addressed, dev = hash of device that triggered notification
#
########################################################################################################

sub Notify ($$) {
  my ($hash,$dev) = @_;
  my $name    = $hash->{NAME};
  my $TYPE    = $hash->{TYPE};
  my $devName = $dev->{NAME};
  my $devType = GetType($devName);

  if ( $devName eq "global" ) {
    my $events = deviceEvents( $dev, 1 );
    return "" unless ($events);

    foreach my $event ( @{$events} ) {
      next unless ( defined($event) );
      next if ( $event =~ m/^[A-Za-z\d_-]+:/ );

      if ( $event =~ m/^INITIALIZED|REREADCFG$/ ) {
        if ( ( defined( $hash->{INTERVAL} ) && $hash->{INTERVAL} > 0 )
            || defined( $hash->{RECOMPUTEAT} ) )
        {
            RemoveInternalTimer($hash);
            InternalTimer(gettimeofday()+5,"FHEM::Astro::Update",$hash,0);
        }
      }
      elsif ( $event =~
          m/^(DEFINED|MODIFIED)\s+([A-Za-z\d_-]+)$/ &&
          $2 eq $name )
      {
        if ( ( defined( $hash->{INTERVAL} ) && $hash->{INTERVAL} > 0 )
            || defined( $hash->{RECOMPUTEAT} ) )
        {
          RemoveInternalTimer($hash);
          InternalTimer(gettimeofday()+1,"FHEM::Astro::Update",$hash,0);
        }
      }
    }
  }

  return undef;
}

########################################################################################################
#
# Attr - Implements Attr function
# 
# Parameter hash = hash of device addressed, ???
#
########################################################################################################

sub Attr(@) {
  my ($do,$name,$key,$value) = @_;
  
  my $hash = $defs{$name};
  my $ret;
  
  if ( $do eq "set") {
    ARGUMENT_HANDLER: {
      #-- altitude modified at runtime
      $key eq "altitude" and do {
        #-- check value
        return "[Astro] $do $name attribute $key must be a float number >= 0 meters"
          unless($value =~ m/^(\d+(?:\.\d+)?)$/ && $1 >= 0.);
      };
      #-- disable modified at runtime
      $key eq "disable" and do {
        #-- check value
        return "[Astro] $do $name attribute $key can only be 1 or 0"
          unless($value =~ m/^(1|0)$/);
        readingsSingleUpdate($hash,"state",$value?"inactive":"Initialized",$init_done);
      };
      #-- earlyfall modified at runtime
      $key eq "earlyfall" and do {
        #-- check value
        return "[Astro] $do $name attribute $key must be in format <month>-<day> while <month> can only be 08 or 09"
          unless($value =~ m/^(0[8-9])-(0[1-9]|[12]\d|30|31)$/);
      };
      #-- earlyspring modified at runtime
      $key eq "earlyspring" and do {
        #-- check value
        return "[Astro] $do $name attribute $key must be in format <month>-<day> while <month> can only be 02 or 03"
          unless($value =~ m/^(0[2-3])-(0[1-9]|[12]\d|30|31)$/);
      };
      #-- horizon modified at runtime
      $key eq "horizon" and do {
        #-- check value
        return "[Astro] $do $name attribute $key must be a float number >= -45 and <= 45 degrees"
          unless($value =~ m/^(-?\d+(?:\.\d+)?)(?::(-?\d+(?:\.\d+)?))?$/ && $1 >= -45. && $1 <= 45. && (!$2 || $2 >= -45. && $2 <= 45.));
      };
      #-- interval modified at runtime
      $key eq "interval" and do {
        #-- check value
        return "[Astro] $do $name attribute $key must be >= 0 seconds"
          unless($value =~ m/^\d+$/);
        #-- update timer
        $hash->{INTERVAL} = $value;
      };
      #-- latitude modified at runtime
      $key eq "latitude" and do {
        #-- check value
        return "[Astro] $do $name attribute $key must be float number >= -90 and <= 90 degrees"
          unless($value =~ m/^(-?\d+(?:\.\d+)?)$/ && $1 >= -90. && $1 <= 90.);
      };
      #-- longitude modified at runtime
      $key eq "longitude" and do {
        #-- check value
        return "[Astro] $do $name attribute $key must be float number >= -180 and <= 180 degrees"
          unless($value =~ m/^(-?\d+(?:\.\d+)?)$/ && $1 >= -180. && $1 <= 180.);
      };
      #-- recomputeAt modified at runtime
      $key eq "recomputeAt" and do {
        my @skel = split(',', $attrs{recomputeAt});
        shift @skel;
        #-- check value 1/2
        return "[Astro] $do $name attribute $key must be one or many of ".join(',', @skel)
          if(!$value || $value eq "");
        #-- check value 2/2
        my @vals = split(',', $value);
        foreach my $val (@vals) {
          return "[Astro] $do $name attribute value $val is invalid, must be one or many of ".join(',', @skel)
            unless(grep( m/^$val$/, @skel ));          
        }
        $hash->{RECOMPUTEAT} = join(',', @vals);
      };
      #-- schedule modified at runtime
      $key eq "schedule" and do {
        my @skel = split(',', $attrs{schedule});
        shift @skel;
        #-- check value 1/2
        return "[Astro] $do $name attribute $key must be one or many of ".join(',', @skel)
          if(!$value || $value eq "");
        #-- check value 2/2
        my @vals = split(',', $value);
        foreach my $val (@vals) {
          return "[Astro] $do $name attribute value $val is invalid, must be one or many of ".join(',', @skel)
            unless(grep( m/^$val$/, @skel ));          
        }
      };
      #-- seasonalHrs modified at runtime
      $key eq "seasonalHrs" and do {
        #-- check value
        return "[Astro] $do $name attribute $key must be an integer number >= 1 and <= 24 hours"
          unless($value =~ m/^(\d+)(?::(\d+))?$/ && $1 >= 1. && $1 <= 24. && (!$2 || $2 >= 1. && $2 <= 24.));
      };
    }
  }

  elsif ( $do eq "del") {
    readingsSingleUpdate($hash,"state","Initialized",$init_done)
      if ($key eq "disable");
    $hash->{INTERVAL} = 3600
      if ($key eq "interval");
    delete $hash->{RECOMPUTEAT}
      if ($key eq "recomputeAt");
  }

  if (   $init_done
      && exists( $attrs{$key} )
      && ( $hash->{INTERVAL} > 0 || $hash->{RECOMPUTEAT} || $hash->{NEXTUPDATE} )
    )
  {
      RemoveInternalTimer($hash);
      InternalTimer( gettimeofday() + 2, "FHEM::Astro::Update", $hash, 0 );
  }

  return $ret;
}

sub _mod($$) { my ($a,$b)=@_;if( $a =~ /\d*\.\d*/){return($a-floor($a/$b)*$b)}else{return undef}; }
sub _mod2Pi($) { my ($x)=@_;$x = _mod($x, 2.*pi);return($x); }
sub _round($$) { my ($x,$n)=@_; return int(10**$n*$x+0.5)/10**$n};

sub _tzoffset($) {
    my ($t)   = @_;
    my $utc   = mktime(gmtime($t));
    #-- the following does not properly calculate dst
    my $local = mktime(localtime($t));
    #-- this is the correction
    my $isdst = (localtime($t))[8];
    #-- correction
    if($isdst == 1){
      $local+=3600;
    }
    return (($local - $utc)/36);
}

########################################################################################################
#
# _Export - Export references to main context using a different naming schema
# 
########################################################################################################

sub _Export {
    no strict qw/refs/;    ## no critic
    my $pkg = caller(0);
    my $main = $pkg;
    $main =~ s/^(?:.+::)?([^:]+)$/main::$1\_/g;
    foreach (@_) {
        *{ $main . $_ } = *{ $pkg . '::' . $_ };
    }
}

########################################################################################################
#
# _LoadOptionalPackages - Load Perl packages that may not be installed
# 
########################################################################################################

sub _LoadOptionalPackages {

    # JSON preference order
    local $ENV{PERL_JSON_BACKEND} =
      'Cpanel::JSON::XS,JSON::XS,JSON::PP,JSON::backportPP'
      unless ( defined( $ENV{PERL_JSON_BACKEND} ) );

    # try to use JSON::MaybeXS wrapper
    #   for chance of better performance + open code
    eval {
        require JSON::MaybeXS;
        $json = JSON::MaybeXS->new;
        1;
    };
    if ($@) {
        $@ = undef;

        # try to use JSON wrapper
        #   for chance of better performance
        eval {
            require JSON;
            $json = JSON->new;
            1;
        };

        if ($@) {
            $@ = undef;

            # In rare cases, Cpanel::JSON::XS may
            #   be installed but JSON|JSON::MaybeXS not ...
            eval {
                require Cpanel::JSON::XS;
                $json = Cpanel::JSON::XS->new;
                1;
            };

            if ($@) {
                $@ = undef;

                # In rare cases, JSON::XS may
                #   be installed but JSON not ...
                eval {
                    require JSON::XS;
                    $json = JSON::XS->new;
                    1;
                };

                if ($@) {
                    $@ = undef;

                    # Fallback to built-in JSON which SHOULD
                    #   be available since 5.014 ...
                    eval {
                        require JSON::PP;
                        $json = JSON::PP->new;
                        1;
                    };

                    if ($@) {
                        $@ = undef;

                        # Last chance may be a backport
                        eval {
                            require JSON::backportPP;
                            $json = JSON::backportPP->new;
                            1;
                        };
                        $@ = undef if ($@);
                    }
                }
            }
        }
    }

    if ($@) {
      $@ = undef;
    } else {
      $json->allow_nonref;
      $json->shrink;
    }
}

########################################################################################################
#
# DistOnEarth - Calculates the distance between two positions on the surface of the earth
#
########################################################################################################

sub DistOnEarth($$$$) {
    my ( $lat1, $lng1, $lat2, $lng2 ) = @_;

    my $aearth = 6378.137;    # GRS80/WGS84 semi major axis of earth ellipsoid

    $lat1 *= $DEG;
    $lng1 *= $DEG;
    $lat2 *= $DEG;
    $lng2 *= $DEG;

    my $dlat = $lat2 - $lat1;
    my $dlng = $lng2 - $lng1;
    my $a =
      sin( $dlat / 2 ) * sin( $dlat / 2 ) +
      cos($lat1) * cos($lat2) * sin( $dlng / 2 ) * sin( $dlng / 2 );
    my $c = 2 * atan2( sqrt($a), sqrt( 1 - $a ) );
    my $dist = $aearth * $c;

    return $dist;
}

########################################################################################################
#
# DaysOfMonth - Returns the ultimo number of days of a specific month in a year
#
########################################################################################################

sub DaysOfMonth ($$) {
    my ( $y, $m ) = @_;
    if ( $m < 8. ) {
        if ( $m % 2 ) {
            return 31.;
        }
        else {
            return 28. + IsLeapYear($y)
              if ( $m == 2. );
            return 30.;
        }
    }
    elsif ( $m % 2. ) {
        return 30.;
    }
    else {
        return 31.;
    }
}

########################################################################################################
#
# IsLeapYear - Returns 1 for a leap year, otherwise 0 (also works for Julian date)
#
########################################################################################################

sub IsLeapYear ($) {
    my $y = shift;
    return 0 if $y % 4;
    return 1 if $y % 100;
    return 0 if $y % 400;
    return 1;
}

########################################################################################################
#
# Deg2CP - numerical degree to compasspoint
#
########################################################################################################

sub Deg2CP($;$$) {
    my ($deg,$txt,$lang) = @_;
    my $i = floor((($deg+11.25)%360)/22.5);
    return $i unless(defined($txt));
    return $compasspoint[$i] if($txt eq '0');

    $lang = uc(AttrVal("global","language","EN")) unless($lang);
    if( exists($transtable{uc($lang)}) ){
      $tt = $transtable{uc($lang)};
    }else{
      $tt = $transtable{EN};
    }
    return $tt->{ $compasspoint[$i] }[1] if ($txt eq '2');
    return $tt->{ $compasspoint[$i] }[0];
}

########################################################################################################
#
# Arabic2Roman - Convert an arabic number into a roman number format
#
########################################################################################################

sub Arabic2Roman ($) {
    my ($n) = @_;
    my %items = ();
    my @r;
    return "" if (!$n || $n eq "" || $n !~ m/^\d+(?:\.\d+)?$/ || $n == 0.);
    return $n
      if ( $n >= 1000001. );    # numbers above cannot be displayed/converted

    for my $v ( sort { $b <=> $a } keys %roman ) {
        my $c = int( $n / $v );
        next unless ($c);
        $items{ $roman{$v} } = $c;
        $n -= $v * $c;
    }

    my @th = sort { $a <=> $b } keys %roman;

    for ( my $i = 0 ; $i < @th ; $i++ ) {
        my $v = $th[$i];
        next if ( $v >= 1000000. );    # numbers above have no greater icon
        my $k = $roman{$v};
        my $c = $items{$k};
        next unless ($c);

        my $gv = $th[ $i + 1. ];
        my $gk = $roman{$gv};

        if ( $c == 4 || ( $gv / $v == $c ) ) {
            $items{$gk}++;
            $c = $gv - $c * $v;
            $items{$k} = $c * -1;

        }
    }

    for my $v ( sort { $b <=> $a } keys %roman ) {
        my $l = $roman{$v};
        my $c = $items{$l};
        next unless ($c);

        if ( $c > 0 ) {
            push @r, $l for ( 1 .. $c );
        }
        else {
            push @r, ( $l, pop @r );
        }
    }

    return join '', @r;
}

########################################################################################################
#
# time fragments into minutes, seconds
#
########################################################################################################  
  
sub HHMM($){
  my ($hh) = @_;
  return("---")
    if (!defined($hh) || $hh !~ /^-?\d+/ || $hh==0) ;
  
  my $h = floor($hh);
  my $m = ($hh-$h)*60.;
  return sprintf("%02d:%02d",$h,$m);
}

sub HHMMSS($){
  my ($hh) = @_;
  return("---")
    if (!defined($hh) || $hh !~ /^-?\d+/ || $hh==0) ;
  
  my $m = ($hh-floor($hh))*60.;
  my $s = ($m-floor($m))*60;
  my $h = floor($hh);
  return sprintf("%02d:%02d:%02d",$h,$m,$s);
}

########################################################################################################
#
# CalcJD - Calculate Julian date: valid only from 1.3.1901 to 28.2.2100
#
########################################################################################################

sub CalcJD($$$) {
  my ($day,$month,$year) = @_;
  my $jd = 2415020.5-64; # 1.1.1900 - correction of algorithm
  if ($month<=2) { 
    $year--; 
    $month += 12; 
  }
  $jd += int( ($year-1900)*365.25 );
  $jd += int( 30.6001*(1+$month) );
  return($jd + $day);
}

########################################################################################################
#
# GMST - Julian Date to Greenwich Mean Sidereal Time
#
########################################################################################################

sub GMST($){
  my ($JD) = @_;
  my $UT   = ($JD-0.5) - int($JD-0.5);
  $UT      = $UT*24.;              # UT in hours
  $JD      = floor($JD-0.5)+0.5;   # JD at 0 hours UT
  my $T    = ($JD-2451545.0)/36525.0;
  my $T0   = 6.697374558 + $T*(2400.051336 + $T*0.000025862);
  
  return( _mod($T0+$UT*1.002737909,24.));
}

########################################################################################################
#
# GMST2UT - Convert Greenweek mean sidereal time to UT
#
########################################################################################################

sub GMST2UT($$){
  my ($JD, $gmst) = @_;
  $JD             = floor($JD-0.5)+0.5;   # JD at 0 hours UT
  my $T           = ($JD-2451545.0)/36525.0;
  my $T0          = _mod(6.697374558 + $T*(2400.051336 + $T*0.000025862), 24.);
  my $UT          = 0.9972695663*(($gmst-$T0));
  return($UT);
}

########################################################################################################
#
# GMST2LMST - Local Mean Sidereal Time, geographical longitude in radians, 
#                   East is positive
#
########################################################################################################

sub GMST2LMST($$){
  my ($gmst, $lon) = @_;
  my $lmst = _mod($gmst+$RAD*$lon/15, 24.);
  return( $lmst );
}

########################################################################################################
#
# Ecl2Equ - Transform ecliptical coordinates (lon/lat) to equatorial coordinates (RA/dec)
#
########################################################################################################

sub Ecl2Equ($$$){
  my ($lon, $lat, $TDT) = @_;
  my $T = ($TDT-2451545.0)/36525.; # Epoch 2000 January 1.5
  my $eps = (23.+(26+21.45/60.)/60. + $T*(-46.815 +$T*(-0.0006 + $T*0.00181) )/3600. )*$DEG;
  my $coseps = cos($eps);
  my $sineps = sin($eps);
  my $sinlon = sin($lon);
  my $ra  = _mod2Pi(atan2( ($sinlon*$coseps-tan($lat)*$sineps), cos($lon) ));  
  my $dec = asin( sin($lat)*$coseps + cos($lat)*$sineps*$sinlon );
 
  return ($ra,$dec);
}

########################################################################################################
#
# Equ2Altaz - Transform equatorial coordinates (RA/Dec) to horizonal coordinates 
#                   (azimuth/altitude). Refraction is ignored
#
########################################################################################################

sub Equ2Altaz($$$$$){
  my ($ra, $dec, $TDT, $lat, $lmst)=@_;
  my $cosdec = cos($dec);
  my $sindec = sin($dec);
  my $lha    = $lmst - $ra;
  my $coslha = cos($lha);
  my $sinlha = sin($lha);
  my $coslat = cos($lat);
  my $sinlat = sin($lat);
  
  my $N      = -$cosdec * $sinlha;
  my $D      = $sindec * $coslat - $cosdec * $coslha * $sinlat;
  my $az     = _mod2Pi( atan2($N, $D) );
  my $alt    = asin( $sindec * $sinlat + $cosdec * $coslha * $coslat );

  return ($az,$alt);
}

########################################################################################################
#
# GeoEqu2TopoEqu - Transform geocentric equatorial coordinates (RA/Dec) to 
#                        topocentric equatorial coordinates
#
########################################################################################################

sub GeoEqu2TopoEqu($$$$$$$){
  my ($ra, $dec, $distance, $lon, $lat, $radius, $lmst) = @_;

  my $cosdec = cos($dec);
  my $sindec = sin($dec);
  my $coslst = cos($lmst);
  my $sinlst = sin($lmst);
  my $coslat = cos($lat); # we should use geocentric latitude, not geodetic latitude
  my $sinlat = sin($lat);
  my $rho    = $radius; # observer-geocenter in km
  
  my $x = $distance*$cosdec*cos($ra) - $rho*$coslat*$coslst;
  my $y = $distance*$cosdec*sin($ra) - $rho*$coslat*$sinlst;
  my $z = $distance*$sindec - $rho*$sinlat;

  my $distanceTopocentric = sqrt($x*$x + $y*$y + $z*$z);
  my $decTopocentric = asin($z/$distanceTopocentric);
  my $raTopocentric = _mod2Pi( atan2($y, $x) );

  return ( ($distanceTopocentric,$decTopocentric,$raTopocentric) );
}

########################################################################################################
#
# EquPolar2Cart - Calculate cartesian from polar coordinates
#
########################################################################################################

sub EquPolar2Cart($$$){
  my ($lon,$lat,$distance) = @_;
  my $rcd = cos($lat)*$distance;
  my $x   = $rcd*cos($lon);
  my $y   = $rcd*sin($lon);
  my $z   = sin($lat)*$distance;
  return( ($x,$y,$z) );
}

########################################################################################################
#
# Observer2EquCart - Calculate observers cartesian equatorial coordinates (x,y,z in celestial frame) 
#                    from geodetic coordinates (longitude, latitude, height above WGS84 ellipsoid)
#                    Currently only used to calculate distance of a body from the observer
#
########################################################################################################

sub Observer2EquCart($$$$){
  my ($lon, $lat, $height, $gmst ) = @_;

  my $flat   = 298.257223563;        # WGS84 flatening of earth
  my $aearth = 6378.137;             # GRS80/WGS84 semi major axis of earth ellipsoid

  #-- Calculate geocentric latitude from geodetic latitude
  my $co = cos ($lat);
  my $si = sin ($lat);
  $si    = $si * $si;
  my $fl = 1.0 - 1.0 / $flat;
  $fl    = $fl * $fl;
  my $u  = 1.0 / sqrt ($co * $co + $fl * $si);
  my $a  = $aearth * $u + $height;
  my $b  = $aearth * $fl * $u + $height;
  my $radius = sqrt ($a * $a * $co *$co + $b *$b * $si); # geocentric distance from earth center
  my $y  = acos ($a * $co / $radius); # geocentric latitude, rad
  my $x  = $lon; # longitude stays the same
  my $z;
  if ($lat < 0.0) { $y = -$y; } # adjust sign
  
  #-- convert from geocentric polar to geocentric cartesian, with regard to Greenwich
  ($x,$y,$z) = EquPolar2Cart( $x, $y, $radius ); 
  
  #-- rotate around earth's polar axis to align coordinate system from Greenwich to vernal equinox
  my $rotangle = $gmst/24*2*pi; # sideral time gmst given in hours. Convert to radians
  my $x2 = $x*cos($rotangle) - $y*sin($rotangle);
  my $y2 = $x*sin($rotangle) + $y*cos($rotangle);
  
  return( ($x2,$y2,$z,$radius) );
}

########################################################################################################
#
# SunPosition - Calculate coordinates for Sun
# Coordinates are accurate to about 10s (right ascension) 
# and a few minutes of arc (declination)
# 
########################################################################################################

sub SunPosition($$$){
  my ($TDT, $observerlat, $lmst)=@_;
  
  my $D  = $TDT-2447891.5;
  my $eg = 279.403303*$DEG;
  my $wg = 282.768422*$DEG;
  my $e  = 0.016713;
  my $a  = 149598500; # km
  #-- mean angular diameter of sun
  my $diameter0 = 0.533128*$DEG; 
  
  my $MSun = 360*$DEG/365.242191*$D+$eg-$wg;
  my $nu   = $MSun + 360.*$DEG/pi*$e*sin($MSun);
  
  my %sunCoor;
  
  $sunCoor{lon}  =  _mod2Pi($nu+$wg);
  $sunCoor{lat}  = 0;
  $sunCoor{anomalyMean} = $MSun;
  
  my $distance  = (1-$e*$e)/(1+$e*cos($nu));   # distance in astronomical units
  $sunCoor{diameter} = $diameter0/$distance;        # angular diameter
  $sunCoor{distance} = $distance*$a;                # distance in km
  $sunCoor{parallax} = 6378.137/$sunCoor{distance};          # horizonal parallax

  ($sunCoor{ra},$sunCoor{dec}) = Ecl2Equ($sunCoor{lon}, $sunCoor{lat}, $TDT);
  
  #-- calculate horizonal coordinates of sun, if geographic positions is given
  if (defined($observerlat) && defined($lmst) ) {
    ($sunCoor{az},$sunCoor{alt}) = Equ2Altaz($sunCoor{ra}, $sunCoor{dec}, $TDT, $observerlat, $lmst);
  }
  $sunCoor{sig} = $zodiac[floor($sunCoor{lon}*$RAD/30)];
  
  return ( \%sunCoor );
}

########################################################################################################
#
# MoonPosition - Calculate data and coordinates for the Moon
#                      Coordinates are accurate to about 1/5 degree (in ecliptic coordinates)
# 
########################################################################################################

sub MoonPosition($$$$$$$){
  my ($sunlon, $sunanomalyMean, $TDT, $observerlon, $observerlat, $observerradius, $lmst) = @_;
  
  my $D = $TDT-2447891.5;
  
  #-- Mean Moon orbit elements as of 1990.0
  my $l0 = 318.351648*$DEG;
  my $P0 =  36.340410*$DEG;
  my $N0 = 318.510107*$DEG;
  my $i  = 5.145396*$DEG;
  my $e  = 0.054900;
  my $a  = 384401; # km
  my $diameter0 = 0.5181*$DEG; # angular diameter of Moon at a distance
  my $parallax0 = 0.9507*$DEG; # parallax at distance a
  
  my $l  = 13.1763966*$DEG*$D+$l0;
  my $MMoon = $l-0.1114041*$DEG*$D-$P0; # Moon's mean anomaly M
  my $N  = $N0-0.0529539*$DEG*$D;          # Moon's mean ascending node longitude
  my $C  = $l-$sunlon;
  my $Ev = 1.2739*$DEG*sin(2*$C-$MMoon);
  my $Ae = 0.1858*$DEG*sin($sunanomalyMean);
  my $A3 = 0.37*$DEG*sin($sunanomalyMean);
  my $MMoon2 = $MMoon+$Ev-$Ae-$A3;  # corrected Moon anomaly
  my $Ec = 6.2886*$DEG*sin($MMoon2);  # equation of centre
  my $A4 = 0.214*$DEG*sin(2*$MMoon2);
  my $l2 = $l+$Ev+$Ec-$Ae+$A4; # corrected Moon's longitude
  my $V  = 0.6583*$DEG*sin(2*($l2-$sunlon));
  my $l3 = $l2+$V; # true orbital longitude;

  my $N2 = $N-0.16*$DEG*sin($sunanomalyMean);
   
  my %moonCoor;
  $moonCoor{lon}      = _mod2Pi( $N2 + atan2( sin($l3-$N2)*cos($i), cos($l3-$N2) ) );
  $moonCoor{lat}      = asin( sin($l3-$N2)*sin($i) );
  $moonCoor{orbitLon} = $l3;
  
  ($moonCoor{ra},$moonCoor{dec}) = Ecl2Equ($moonCoor{lon},$moonCoor{lat},$TDT);
  #-- relative distance to semi mayor axis of lunar oribt
  my $distance = (1-$e*$e) / (1+$e*cos($MMoon2+$Ec) );
  $moonCoor{diameter} = $diameter0/$distance; # angular diameter in radians
  $moonCoor{parallax} = $parallax0/$distance; # horizontal parallax in radians
  $moonCoor{distance} = $distance*$a;         # distance in km

  #-- Calculate horizonal coordinates of moon, if geographic positions is given

  #-- backup geocentric coordinates
  $moonCoor{raGeocentric}       = $moonCoor{ra}; 
  $moonCoor{decGeocentric}      = $moonCoor{dec};
  $moonCoor{distanceGeocentric} = $moonCoor{distance};

  if (defined($observerlat) && defined($observerlon) && defined($lmst) ) {
    #-- transform geocentric coordinates into topocentric (==observer based) coordinates
	my  ($distanceTopocentric,$decTopocentric,$raTopocentric) = 
	  GeoEqu2TopoEqu($moonCoor{ra}, $moonCoor{dec}, $moonCoor{distance}, $observerlon, $observerlat, $observerradius, $lmst);
	#-- now ra and dec are topocentric
	$moonCoor{ra}  = $raTopocentric;
	$moonCoor{dec} = $decTopocentric;
    ($moonCoor{az},$moonCoor{alt})= Equ2Altaz($moonCoor{ra}, $moonCoor{dec}, $TDT, $observerlat, $lmst); 
  }
  
  #-- Age of Moon in radians since New Moon (0) - Full Moon (pi)
  $moonCoor{age}    = _mod2Pi($l3-$sunlon);   
  $moonCoor{phasen} = 0.5*(1-cos($moonCoor{age})); # Moon phase numerical, 0-1
  
  my $mainPhase = 1./29.53*360*$DEG; # show 'Newmoon, 'Quarter' for +/-1 day around the actual event
  my $p = _mod($moonCoor{age}, 90.*$DEG);
  if ($p < $mainPhase || $p > 90*$DEG-$mainPhase){
    $p = 2*floor($moonCoor{age} / (90.*$DEG)+0.5);
  }else{
    $p = 2*floor($moonCoor{age} / (90.*$DEG))+1;
  }
  $p = $p % 8;
  $moonCoor{phases} = $phases[$p]; 
  $moonCoor{phasei} = $p;
  $moonCoor{sig}    = $zodiac[floor($moonCoor{lon}*$RAD/30)];

  return ( \%moonCoor );
}

########################################################################################################
#
# Refraction - Input true altitude in radians, Output: increase in altitude in degrees
# 
########################################################################################################

sub Refraction($){
  my ($alt) = @_;
  my $altdeg = $alt*$RAD;
  if ($altdeg<-2 || $altdeg>=90){
    return(0);
  }
   
  my $pressure    = 1015;
  my $temperature = 10;
  if ($altdeg>15){
    return( 0.00452*$pressure/( (273+$temperature)*tan($alt)) );
  }
  
  my $y = $alt;
  my $D = 0.0;
  my $P = ($pressure-80.)/930.;
  my $Q = 0.0048*($temperature-10.);
  my $y0 = $y;
  my $D0 = $D;
  my $N;

  for (my $i=0; $i<3; $i++) {
	$N = $y+(7.31/($y+4.4));
    $N = 1./tan($N*$DEG);
	$D = $N*$P/(60.+$Q*($N+39.));
	$N = $y-$y0;
	$y0 = $D-$D0-$N;
	if (($N != 0.) && ($y0 != 0.)) { 
	  $N = $y-$N*($alt+$D-$y)/$y0; 
	} else { 
	  $N = $alt+$D; 
	}
	$y0 = $y;
	$D0 = $D;
	$y  = $N;
  }
  return( $D ); 
}

########################################################################################################
#
# GMSTRiseSet - returns Greenwich sidereal time (hours) of time of rise 
# and set of object with coordinates ra/dec
# at geographic position lon/lat (all values in radians)
# Correction for refraction and semi-diameter/parallax of body is taken care of in function RiseSet
# h is used to calculate the twilights. It gives the required elevation of the disk center of the sun
# 
########################################################################################################

sub GMSTRiseSet($$$$$){
  my ($ra, $dec, $lon, $lat, $h) = @_;
  
  $h = (defined($h)) ? $h : 0.0; # set default value
  #Log 1,"-------------------> Called GMSTRiseSet with $ra $dec $lon $lat $h";

  # my $tagbogen = acos(-tan(lat)*tan(coor.dec)); // simple formula if twilight is not required
  my $tagbarg  = (sin($h) - sin($lat)*sin($dec)) / (cos($lat)*cos($dec));
  if( ($tagbarg > 1.000000) || ($tagbarg < -1.000000) ){
    Log 5,"[FHEM::Astro::GMSTRiseSet] Parameters $ra $dec $lon $lat $h give complex angle";
    return( ("---","---","---") );
  };
  my $tagbogen = acos($tagbarg);

  my $transit =     $RAD/15*(          +$ra-$lon);
  my $rise    = 24.+$RAD/15*(-$tagbogen+$ra-$lon); # calculate GMST of rise of object
  my $set     =     $RAD/15*(+$tagbogen+$ra-$lon); # calculate GMST of set of object

  #--Using the modulo function mod, the day number goes missing. This may get a problem for the moon
  $transit = _mod($transit, 24);
  $rise    = _mod($rise, 24);
  $set     = _mod($set, 24);
  
  return( ($transit, $rise, $set) );
}

########################################################################################################
#
# InterpolateGMST - Find GMST of rise/set of object from the two calculated 
# (start)points (day 1 and 2) and at midnight UT(0)
# 
########################################################################################################

sub InterpolateGMST($$$$){
  my ($gmst0, $gmst1, $gmst2, $timefactor) = @_;
  return( ($timefactor*24.07*$gmst1- $gmst0*($gmst2-$gmst1)) / ($timefactor*24.07+$gmst1-$gmst2) );
}

########################################################################################################
#
# RiseSet
#    // JD is the Julian Date of 0h UTC time (midnight)
# 
########################################################################################################

sub RiseSet($$$$$$$$$$$){
  my ($jd0UT, $diameter, $parallax, $ra1, $dec1, $ra2, $dec2, $lon, $lat, $timeinterval, $altip) = @_;
 
  #--altitude of sun center: semi-diameter, horizontal parallax and (standard) refraction of 34'
  #  true height of sun center for sunrise and set calculation. Is kept 0 for twilight (ie. altitude given):
  my $alt      = (!defined($altip)) ? 0.5*$diameter-$parallax+34./60*$DEG : 0.; 
  my $altitude = (!defined($altip)) ? 0. : $altip; 

  my ($transit1, $rise1, $set1) = GMSTRiseSet($ra1, $dec1, $lon, $lat, $altitude);
  my ($transit2, $rise2, $set2) = GMSTRiseSet($ra2, $dec2, $lon, $lat, $altitude);
  
  #-- complex angle
  if( ($transit1 eq "---") || ($transit2 eq "---") ){
    return( ("---","---","---") );
  }
  
  #-- unwrap GMST in case we move across 24h -> 0h
  $transit2 += 24
    if ($transit1 > $transit2 && abs($transit1-$transit2)>18);
  $rise2 += 24
    if ($rise1 > $rise2    && abs($rise1-$rise2)>18);
  $set2 += 24
    if ($set1 > $set2    && abs($set1-$set2)>18);
    
  my $T0 = GMST($jd0UT);
  # my $T02 = T0-zone*1.002738; // Greenwich sidereal time at 0h time zone (zone: hours)
  #-- Greenwich sidereal time for 0h at selected longitude
  my $T02 = $T0-$lon*$RAD/15*1.002738;
  $T02 +=24 if ($T02 < 0);

  if ($transit1 < $T02) { 
    $transit1 += 24; 
    $transit2 += 24; 
  }
  if ($rise1    < $T02) { 
    $rise1    += 24; 
    $rise2    += 24; 
  }
  if ($set1     < $T02) { 
    $set1     += 24; 
    $set2     += 24; 
  }
  
  #-- Refraction and Parallax correction
  my $decMean = 0.5*($dec1+$dec2);
  my $psi = acos(sin($lat)/cos($decMean));
  my $y   = asin(sin($alt)/sin($psi));
  my $dt  = 240*$RAD*$y/cos($decMean)/3600; # time correction due to refraction, parallax

  my $transit = GMST2UT( $jd0UT, InterpolateGMST( $T0, $transit1, $transit2, $timeinterval) );
  my $rise    = GMST2UT( $jd0UT, InterpolateGMST( $T0, $rise1,    $rise2,    $timeinterval) - $dt );
  my $set     = GMST2UT( $jd0UT, InterpolateGMST( $T0, $set1,     $set2,     $timeinterval) + $dt );
  
  return( ($transit,$rise,$set) ); 
}

########################################################################################################
#
# SunRise - Find (local) time of sunrise and sunset, and twilights
#                 JD is the Julian Date of 0h local time (midnight)
#                 Accurate to about 1-2 minutes
#                 recursive: 1 - calculate rise/set in UTC in a second run
#                 recursive: 0 - find rise/set on the current local day. 
#                                This is set when doing the first call to this function
# 
########################################################################################################

sub SunRise($$$$$$$$){
  my ($JD, $deltaT, $lon, $lat, $zone, $horM, $horE, $recursive) = @_;
  
  my $jd0UT = floor($JD-0.5)+0.5;   # JD at 0 hours UT
  
  #-- calculations for noon
  my $sunCoor1 = SunPosition($jd0UT+   $deltaT/24./3600.,undef,undef);

  #-- calculations for next day's UTC midnight
  my $sunCoor2 = SunPosition($jd0UT+1.+$deltaT/24./3600.,undef,undef); 
  
  #-- rise/set time in UTC
  my ($transit,$rise,$set) = RiseSet($jd0UT, $sunCoor1->{diameter}, $sunCoor1->{parallax}, 
    $sunCoor1->{ra}, $sunCoor1->{dec}, $sunCoor2->{ra}, $sunCoor2->{dec}, $lon, $lat, 1,undef); 
  if( $transit eq "---" ){
    Log 3,"[FHEM::Astro::SunRise] no solution possible - maybe the sun never sets ?";
   return( ($transit,$rise,$set) ); 
  }
  
  my ($transittemp,$risetemp,$settemp);
  #-- check and adjust to have rise/set time on local calendar day
  if ( $recursive==0 ) { 
    if ($zone>0) {
      #rise time was yesterday local time -> calculate rise time for next UTC day
      if ($rise >=24-$zone || $transit>=24-$zone || $set>=24-$zone) {
        ($transittemp,$risetemp,$settemp) = SunRise($JD+1, $deltaT, $lon, $lat, $zone, $horM, $horE, 1);
        $transit = $transittemp
          if ($transit>=24-$zone);
        $rise = $risetemp
          if ($rise>=24-$zone);
        $set = $settemp
          if ($set>=24-$zone);
      }
    }elsif ($zone<0) {
      #rise time was yesterday local time -> calculate rise time for previous UTC day
      if ($rise<-$zone || $transit<-zone || $set<-zone) {
        ($transittemp,$risetemp,$settemp) = SunRise($JD-1, $deltaT, $lon, $lat, $zone, $horM, $horE, 1);
      $transit = $transittemp
        if ($transit<-$zone);
      $rise = $risetemp
        if ($rise<-$zone);
      $set  = $settemp
        if ($set <-$zone);
      }
    }
	
    $transit = _mod($transit+$zone, 24.);
    $rise    = _mod($rise   +$zone, 24.);
    $set     = _mod($set    +$zone, 24.);

	#-- Twilight calculation
	#-- civil twilight time in UTC. 
	my $CivilTwilightMorning;
	my $CivilTwilightEvening;
	($transittemp,$risetemp,$settemp) = RiseSet($jd0UT, $sunCoor1->{diameter}, $sunCoor1->{parallax}, 
	   $sunCoor1->{ra}, $sunCoor1->{dec}, $sunCoor2->{ra}, $sunCoor2->{dec}, $lon, $lat, 1, -6.*$DEG);
	if( $transittemp eq "---" ){
      Log 4,"[FHEM::Astro::SunRise] no solution possible for civil twilight - maybe the sun never sets below -6 degrees?";
      $CivilTwilightMorning = "---";
      $CivilTwilightEvening = "---";
    }else{
	  $CivilTwilightMorning = _mod($risetemp +$zone, 24.);
	  $CivilTwilightEvening = _mod($settemp  +$zone, 24.);
    }
    
	#-- nautical twilight time in UTC.
	my $NauticTwilightMorning;
	my $NauticTwilightEvening; 
	($transittemp,$risetemp,$settemp) = RiseSet($jd0UT, $sunCoor1->{diameter}, $sunCoor1->{parallax}, 
	  $sunCoor1->{ra}, $sunCoor1->{dec}, $sunCoor2->{ra}, $sunCoor2->{dec}, $lon, $lat, 1, -12.*$DEG);
	if( $transittemp eq "---" ){
      Log 4,"[FHEM::Astro::SunRise] no solution possible for nautical twilight - maybe the sun never sets below -12 degrees?";
      $NauticTwilightMorning = "---";
      $NauticTwilightEvening = "---";
    }else{
      $NauticTwilightMorning = _mod($risetemp +$zone, 24.);
	  $NauticTwilightEvening = _mod($settemp  +$zone, 24.);
	}

	#-- astronomical twilight time in UTC. 
	my $AstroTwilightMorning;
	my $AstroTwilightEvening;
	($transittemp,$risetemp,$settemp) = RiseSet($jd0UT, $sunCoor1->{diameter}, $sunCoor1->{parallax}, 
	  $sunCoor1->{ra}, $sunCoor1->{dec}, $sunCoor2->{ra}, $sunCoor2->{dec}, $lon, $lat, 1, -18.*$DEG);
	if( $transittemp eq "---" ){
      Log 4,"[FHEM::Astro::SunRise] no solution possible for astronomical twilight - maybe the sun never sets below -18 degrees?";
      $AstroTwilightMorning = "---";
      $AstroTwilightEvening = "---";
    }else{
	  $AstroTwilightMorning = _mod($risetemp +$zone, 24.);
	  $AstroTwilightEvening = _mod($settemp  +$zone, 24.);
	}
	
	#-- custom twilight time in UTC
	my $CustomTwilightMorning;
	my $CustomTwilightEvening;
    ($transittemp,$risetemp,$settemp) = RiseSet($jd0UT, $sunCoor1->{diameter}, $sunCoor1->{parallax}, 
	  $sunCoor1->{ra}, $sunCoor1->{dec}, $sunCoor2->{ra}, $sunCoor2->{dec}, $lon, $lat, 1, $horM*$DEG);
	if( $transittemp eq "---" ){
      Log 4,"[FHEM::Astro::SunRise] no solution possible for custom morning twilight - maybe the sun never sets below ".$horM." degrees?";
      $CustomTwilightMorning = "---";
    }else{
	  $CustomTwilightMorning = _mod($risetemp +$zone, 24.);
	}
    ($transittemp,$risetemp,$settemp) = RiseSet($jd0UT, $sunCoor1->{diameter}, $sunCoor1->{parallax}, 
    $sunCoor1->{ra}, $sunCoor1->{dec}, $sunCoor2->{ra}, $sunCoor2->{dec}, $lon, $lat, 1, $horE*$DEG);
  if( $transittemp eq "---" ){
      Log 4,"[FHEM::Astro::SunRise] no solution possible for custom evening twilight - maybe the sun never sets below ".$horE." degrees?";
      $CustomTwilightEvening = "---";
    }else{
    $CustomTwilightEvening = _mod($settemp  +$zone, 24.);
  }
	
	return( ($transit,$rise,$set,$CivilTwilightMorning,$CivilTwilightEvening,
	  $NauticTwilightMorning,$NauticTwilightEvening,$AstroTwilightMorning,$AstroTwilightEvening,$CustomTwilightMorning,$CustomTwilightEvening) );  
  }else{
    return( ($transit,$rise,$set) );  
  }
}

########################################################################################################
#
# MoonRise - Find local time of moonrise and moonset
# JD is the Julian Date of 0h local time (midnight)
# Accurate to about 5 minutes or better
# recursive: 1 - calculate rise/set in UTC
# recursive: 0 - find rise/set on the current local day (set could also be first)
# returns '' for moonrise/set does not occur on selected day
# 
########################################################################################################

sub MoonRise($$$$$$$){
  my ($JD, $deltaT, $lon, $lat, $radius, $zone, $recursive) = @_;
  my $timeinterval = 0.5;
  
  my $jd0UT = floor($JD-0.5)+0.5;   # JD at 0 hours UT
  #-- calculations for noon
  my $sunCoor1  = SunPosition($jd0UT+ $deltaT/24./3600.,undef,undef);
  my $moonCoor1 = MoonPosition($sunCoor1->{lon}, $sunCoor1->{anomalyMean}, $jd0UT+ $deltaT/24./3600.,undef,undef,undef,undef);
 
  #-- calculations for next day's midnight
  my $sunCoor2  = SunPosition($jd0UT +$timeinterval + $deltaT/24./3600.,undef,undef); 
  my $moonCoor2 = MoonPosition($sunCoor2->{lon}, $sunCoor2->{anomalyMean}, $jd0UT +$timeinterval + $deltaT/24./3600.,undef,undef,undef,undef); 

  # rise/set time in UTC, time zone corrected later.
  # Taking into account refraction, semi-diameter and parallax
  my ($transit,$rise,$set) = RiseSet($jd0UT, $moonCoor1->{diameter}, $moonCoor1->{parallax}, 
    $moonCoor1->{ra}, $moonCoor1->{dec}, $moonCoor2->{ra}, $moonCoor2->{dec}, $lon, $lat, $timeinterval,undef); 
  my ($transittemp,$risetemp,$settemp);
  my ($transitprev,$riseprev,$setprev);
  
  # check and adjust to have rise/set time on local calendar day
  if ( $recursive==0 ) { 
    if ($zone>0) {
      # recursive call to MoonRise returns events in UTC
      ($transitprev,$riseprev,$setprev) = MoonRise($JD-1., $deltaT, $lon, $lat, $radius, $zone, 1);  
      if ($transit >= 24.-$zone || $transit < -$zone) { # transit time is tomorrow local time
        if ($transitprev < 24.-$zone){
           $transit = ""; # there is no moontransit today
        }else{
           $transit  = $transitprev;
        }
      }
      
      if ($rise >= 24.-$zone || $rise < -$zone) { # rise time is tomorrow local time
        if ($riseprev < 24.-$zone){
          $rise = ""; # there is no moonrise today
        }else{ 
          $rise  = $riseprev;
        }
      }

      if ($set >= 24.-$zone || $set < -$zone) { # set time is tomorrow local time
        if ($setprev < 24.-$zone){
          $set = ""; # there is no moonset today
        }else{
          $set  = $setprev;
        }
      }

    }elsif ($zone<0) { # rise/set time was tomorrow local time -> calculate rise time for previous UTC day
      if ($rise<-$zone || $set<-$zone || $transit<-$zone) { 
        ($transittemp,$risetemp,$settemp) = MoonRise($JD+1., $deltaT, $lon, $lat, $radius, $zone, 1);  
        if ($transit < -$zone){
          if ($transittemp > -$zone){
            $transit = ''; # there is no moontransit today
          }else{
            $transit  = $transittemp;
          }
        }
        
        if ($rise < -$zone) {
          if ($risetemp > -$zone){
             $rise = ''; # there is no moonrise today
          }else{
             $rise = $risetemp;
          }
        }
        
        if ($set < -$zone){
          if ($settemp > -$zone){
            $set = ''; # there is no moonset today
          }else{
            $set  = $settemp;
          }
        }     
      }
    }
    #-- correct for time zone, if time is valid
    $transit = _mod($transit +$zone, 24.)
      if( $transit ne ""); 
    $rise = _mod($rise +$zone, 24.)
      if ($rise ne "");    
    $set  = _mod($set +$zone, 24.)
      if ($set ne "");   
  }
  return( ($transit,$rise,$set) );
}

########################################################################################################
#
# SetTime - update of the %Date hash for today +/- 2 days
# 
########################################################################################################

sub SetTime (;$$) {
    my ( $time, $dayOffset ) = @_;
    $time = gettimeofday() unless ( defined($time) );
    $dayOffset = 2 unless ( defined($dayOffset) );
    my $D = $dayOffset ? \%Date : {};

    my ( $sec, $min, $hour, $day, $month, $year, $wday, $yday, $isdst ) =
      localtime($time);
    my $isdstnoon =
      ( localtime( timelocal( 0, 0, 12, $day, $month, $year ) ) )[8];
    $year  += 1900;
    $month += 1;
    $D->{timestamp} = $time;
    $D->{timeday}   = $hour + $min / 60. + $sec / 3600.;
    $D->{year}      = $year;
    $D->{month}     = $month;
    $D->{day}       = $day;
    $D->{hour}      = $hour;
    $D->{min}       = $min;
    $D->{sec}       = $sec;
    $D->{isdst}     = $isdst;
    $D->{isdstnoon} = $isdstnoon;

    #-- broken on windows
    #$D->{zonedelta} = (strftime "%z", localtime)/100;
    $D->{zonedelta} = _tzoffset($time) / 100;

    #-- half broken in windows
    $D->{dayofyear} = 1 * strftime( "%j", localtime($time) );

    $D->{weekofyear}    = 1 * strftime( "%V", localtime($time) );
    $D->{isly}          = IsLeapYear($year);
    $D->{yearremdays}   = 365. + $D->{isly} - $D->{dayofyear};
    $D->{yearprogress}  = $D->{dayofyear} / ( 365. + $D->{isly} );
    $D->{monthremdays}  = DaysOfMonth( $D->{year}, $D->{month} ) - $D->{day};
    $D->{monthprogress} = $D->{day} / DaysOfMonth( $D->{year}, $D->{month} );

    #-- add info from X days before+after
    if ($dayOffset) {
        my $i = $dayOffset * -1.;
        while ( $i < $dayOffset + 1. ) {
            $D->{$i} = SetTime( $time + ( 86400. * $i ), 0 )
              unless ( $i == 0 );
            $i++;
        }
    }
    else {
        return $D;
    }

    return (undef);
}

########################################################################################################
#
# Compute - sequential calculation of properties
# 
########################################################################################################
  
sub Compute($;$$){
  my ($hash,$dayOffset,$params) = @_;
  undef %Astro unless($dayOffset);
  SetTime() if (scalar keys %Date == 0); # fill %Date if it is still empty after restart
  my $A = $dayOffset ? {} : \%Astro;
  my $D = $dayOffset ? $Date{$dayOffset} : \%Date;

  my $name = $hash->{NAME};

  return undef if( !$init_done );

  #-- readjust language
  my $lang = uc(AttrVal($name,"language",AttrVal("global","language","EN")));
  if( defined($params->{"language"}) &&
      exists($transtable{uc($params->{"language"})})
  ){
    $tt = $transtable{uc($params->{"language"})};
  }elsif( exists($transtable{uc($lang)}) ){
    $tt = $transtable{uc($lang)};
  }else{
    $tt = $transtable{EN};
  }

  #-- load schedule schema
  my @schedsch =
    split(
      ',',
      (
          defined( $params->{"schedule"} )
          ? $params->{"schedule"}
          : AttrVal( $name, "schedule", $attrs{schedule} )
      )
    );

  #-- geodetic latitude and longitude of observer on WGS84  
  if( defined($params->{"latitude"}) ){
    $A->{ObsLat}  = $params->{"latitude"};
  }elsif( defined($attr{$name}) && defined($attr{$name}{"latitude"}) ){
    $A->{ObsLat}  = $attr{$name}{"latitude"};
  }elsif( defined($attr{"global"}{"latitude"}) ){
    $A->{ObsLat}  = $attr{"global"}{"latitude"};
  }else{
    $A->{ObsLat}  = 50.0;
    Log3 $name,3,"[Astro] No latitude attribute set in global device, using 50.0°"
      if (!$dayOffset);
  }
  if( defined($params->{"longitude"}) ){
    $A->{ObsLon}  = $params->{"longitude"};
  }elsif( defined($attr{$name}) && defined($attr{$name}{"longitude"}) ){
    $A->{ObsLon}  = $attr{$name}{"longitude"};
  }elsif( defined($attr{"global"}{"longitude"}) ){
    $A->{ObsLon}  = $attr{"global"}{"longitude"};
  }else{
    $A->{ObsLon}  = 10.0;
    Log3 $name,3,"[Astro] No longitude attribute set in global device, using 10.0°"
      if (!$dayOffset);
  } 
  #-- altitude of observer in meters above WGS84 ellipsoid 
  if( defined($params->{"altitude"}) ){
    $A->{ObsAlt}  = $params->{"altitude"};
  }elsif( defined($attr{$name}) && defined($attr{$name}{"altitude"}) ){
    $A->{ObsAlt}  = $attr{$name}{"altitude"};
  }elsif( defined($attr{"global"}{"altitude"}) ){
    $A->{ObsAlt}  = $attr{"global"}{"altitude"};
  }else{
    $A->{ObsAlt}  = 0.0;
    Log3 $name,3,"[Astro] No altitude attribute set in global device, using 0.0 m above sea level"
      if (!$dayOffset);
  }
  #-- custom horizon of observer in degrees
  if( defined($params->{"horizon"}) &&
      $params->{"horizon"} =~ m/^([^:]+)(?::(.+))?$/
  ){
    $A->{ObsHorMorning} = $1;
    $A->{ObsHorEvening} = defined($2) ? $2 : $1;
  }elsif( defined($attr{$name}) && defined($attr{$name}{"horizon"}) &&
      $attr{$name}{"horizon"} =~ m/^([^:]+)(?::(.+))?$/
  ){
    $A->{ObsHorMorning} = $1;
    $A->{ObsHorEvening} = defined($2) ? $2 : $1;
  } else {
    $A->{ObsHorMorning} = 0.0;
    $A->{ObsHorEvening} = 0.0;
    Log3 $name,5,"[Astro] No horizon attribute defined, using 0.0° for morning and evening"
      if (!$dayOffset);
  }
  #-- custom date for early spring
  my $earlyspring = '02-22';
  if( defined($params->{"earlyspring"}) ){
    $earlyspring  = $params->{"earlyspring"};
  }elsif( defined($attr{$name}) && defined($attr{$name}{"earlyspring"}) ){
    $earlyspring  = $attr{$name}{"earlyspring"};
  } else {
    Log3 $name,5,"[Astro] No earlyspring attribute defined, using date $earlyspring"
      if (!$dayOffset);
  }
  #-- custom date for early fall
  my $earlyfall = '08-20';
  if( defined($params->{"earlyfall"}) ){
    $earlyfall  = $params->{"earlyfall"};
  }elsif( defined($attr{$name}) && defined($attr{$name}{"earlyfall"}) ){
    $earlyfall  = $attr{$name}{"earlyfall"};
  } else {
    Log3 $name,5,"[Astro] No earlyfall attribute defined, using date $earlyfall"
      if (!$dayOffset);
  }
  #-- custom number for seasonal hours
  my $daypartsIsRoman = 0;
  my $dayparts        = 12;
  my $nightparts      = 12;
  if( defined($params->{"seasonalHrs"}) &&
      $params->{"seasonalHrs"} =~ m/^(([^:]+)(?::(.+))?)$/
  ){
    $daypartsIsRoman = 1 if ($1 eq '4'); # special handling of '^4$' as roman format
    $dayparts   = $daypartsIsRoman ? 12. : $2;
    $nightparts = $3 ? $3 : $2;
  }elsif( defined($attr{$name}) && defined($attr{$name}{"seasonalHrs"}) &&
      $attr{$name}{"seasonalHrs"} =~ m/^(([^:]+)(?::(.+))?)$/
  ){
    $daypartsIsRoman = 1 if ($1 eq '4'); # special handling of '^4$' as roman format
    $dayparts   = $daypartsIsRoman ? 12. : $2;
    $nightparts = $3 ? $3 : $2;
  } else {
    Log3 $name,5,"[Astro] No seasonalHrs attribute defined, using $dayparts seasonal hours for day and night"
      if (!$dayOffset);
  }

  #-- add info from 2 days after but only +1 day will be useful after all
  if (!defined($dayOffset)) {
    $A->{2}     = Compute($hash, 2, $params);   # today+2, has no tomorrow or yesterday
    $A->{1}     = Compute($hash, 1, $params);   # today+1, only has tomorrow and incomplete yesterday
  }

  #-- reference for tomorrow
  my $At;
  if (!defined($dayOffset) || $dayOffset == -1. || $dayOffset == 0. || $dayOffset == 1. ) {
    my $t = (!defined($dayOffset)?0.:$dayOffset) + 1.;
    $At = \%Astro unless ($t);
    $At = $Astro{$t} if ($t && defined($Astro{$t}));
  }

  #-- internal variables converted to Radians and km 
  my $lat      = $A->{ObsLat}*$DEG;
  my $lon      = $A->{ObsLon}*$DEG;
  my $height   = $A->{ObsAlt} * 0.001;   

  #if (eval(form.Year.value)<=1900 || eval(form.Year.value)>=2100 ) {
  #  alert("Dies Script erlaubt nur Berechnungen"+
  #  return;
  #}

  my $JD0 = CalcJD( $D->{day}, $D->{month}, $D->{year} );
  my $JD  = $JD0 + ( $D->{hour} - $D->{zonedelta} + $D->{min}/60. + $D->{sec}/3600.)/24;
  my $TDT = $JD  + $deltaT/86400.0; 
  
  $A->{".ObsJD"}  = $JD;
  $A->{ObsJD}     = _round($JD,2);

  my $gmst          = GMST($JD);
  my $lmst          = GMST2LMST($gmst, $lon); 
  $A->{".ObsGMST"}  = $gmst;
  $A->{".ObsLMST"}  = $lmst;
  $A->{ObsGMST}     = HHMMSS($gmst);
  $A->{ObsLMST}     = HHMMSS($lmst);
  
  #-- geocentric cartesian coordinates of observer
  my ($x,$y,$z,$radius) = Observer2EquCart($lon, $lat, $height, $gmst); 
 
  #-- calculate data for the sun at given time
  my $sunCoor   = SunPosition($TDT, $lat, $lmst*15.*$DEG);   
  $A->{".SunLon"}      = $sunCoor->{lon}*$RAD;
  #$A->{"SunLat"}       = $sunCoor->{lat}*$RAD;
  $A->{".SunRa"}       = $sunCoor->{ra} *$RAD/15;
  $A->{".SunDec"}      = $sunCoor->{dec}*$RAD;
  $A->{".SunAz"}       = $sunCoor->{az} *$RAD;
  $A->{".SunAlt"}      = $sunCoor->{alt}*$RAD + Refraction($sunCoor->{alt});  # including refraction WARNUNG => *RAD ???
  $A->{".SunDiameter"} = $sunCoor->{diameter}*$RAD*60; #angular diameter in arc seconds
  $A->{".SunDistance"} = $sunCoor->{distance};
  $A->{SunLon}      = _round($A->{".SunLon"},1);
  #$A->{SunLat}      = $sunCoor->{lat}*$RAD;
  $A->{SunRa}       = _round($A->{".SunRa"},1);
  $A->{SunDec}      = _round($A->{".SunDec"},1);
  $A->{SunAz}       = _round($A->{".SunAz"},1);
  $A->{SunCompassI} = Deg2CP($A->{".SunAz"});
  $A->{SunCompass}  = $tt->{Deg2CP($A->{".SunAz"},0)}[0];
  $A->{SunCompassS} = $tt->{Deg2CP($A->{".SunAz"},0)}[1];
  $A->{SunAlt}      = _round($A->{".SunAlt"},1);
  $A->{SunSign}     = $tt->{$sunCoor->{sig}};
  $A->{SunDiameter} = _round($A->{".SunDiameter"},1);
  $A->{SunDistance} = _round($A->{".SunDistance"},0);
  
  #-- calculate distance from the observer (on the surface of earth) to the center of the sun
  my ($xs,$ys,$zs) = EquPolar2Cart($sunCoor->{ra}, $sunCoor->{dec}, $sunCoor->{distance});
  $A->{".SunDistanceObserver"} = sqrt( ($xs-$x)**2 + ($ys-$y)**2 + ($zs-$z)**2 );
  $A->{SunDistanceObserver} = _round($A->{".SunDistanceObserver"},0);
  
  my ($suntransit,$sunrise,$sunset,$CivilTwilightMorning,$CivilTwilightEvening,
    $NauticTwilightMorning,$NauticTwilightEvening,$AstroTwilightMorning,$AstroTwilightEvening,$CustomTwilightMorning,$CustomTwilightEvening) = 
    SunRise($JD0, $deltaT, $lon, $lat, $D->{zonedelta}, $A->{ObsHorMorning}, $A->{ObsHorEvening}, 0);
  $A->{".SunTransit"}            = $suntransit;
  $A->{".SunRise"}               = $sunrise;
  $A->{".SunSet"}                = $sunset;
  $A->{".CivilTwilightMorning"}  = $CivilTwilightMorning;
  $A->{".CivilTwilightEvening"}  = $CivilTwilightEvening;
  $A->{".NauticTwilightMorning"} = $NauticTwilightMorning;
  $A->{".NauticTwilightEvening"} = $NauticTwilightEvening;
  $A->{".AstroTwilightMorning"}  = $AstroTwilightMorning;
  $A->{".AstroTwilightEvening"}  = $AstroTwilightEvening;
  $A->{".CustomTwilightMorning"} = $CustomTwilightMorning;
  $A->{".CustomTwilightEvening"} = $CustomTwilightEvening;
  $A->{SunTransit}              = HHMM($suntransit);
  $A->{SunRise}                 = HHMM($sunrise);
  $A->{SunSet}                  = HHMM($sunset);
  $A->{CivilTwilightMorning}    = HHMM($CivilTwilightMorning);
  $A->{CivilTwilightEvening}    = HHMM($CivilTwilightEvening);
  $A->{NauticTwilightMorning}   = HHMM($NauticTwilightMorning);
  $A->{NauticTwilightEvening}   = HHMM($NauticTwilightEvening);
  $A->{AstroTwilightMorning}    = HHMM($AstroTwilightMorning);
  $A->{AstroTwilightEvening}    = HHMM($AstroTwilightEvening);
  $A->{CustomTwilightMorning}   = HHMM($CustomTwilightMorning);
  $A->{CustomTwilightEvening}   = HHMM($CustomTwilightEvening);
  AddToSchedule($A, $suntransit, "SunTransit")
    if (grep (/^SunTransit/, @schedsch));
  AddToSchedule($A, $sunrise, "SunRise")
    if (grep (/^SunRise/, @schedsch));
  AddToSchedule($A, $sunset, "SunSet")
    if (grep (/^SunSet/, @schedsch));
  AddToSchedule($A, $CivilTwilightMorning, "CivilTwilightMorning")
    if (grep (/^CivilTwilightMorning/, @schedsch));
  AddToSchedule($A, $CivilTwilightEvening, "CivilTwilightEvening")
    if (grep (/^CivilTwilightEvening/, @schedsch));
  AddToSchedule($A, $NauticTwilightMorning, "NauticTwilightMorning")
    if (grep (/^NauticTwilightMorning/, @schedsch));
  AddToSchedule($A, $NauticTwilightEvening, "NauticTwilightEvening")
    if (grep (/^NauticTwilightEvening/, @schedsch));
  AddToSchedule($A, $AstroTwilightMorning, "AstroTwilightMorning")
    if (grep (/^AstroTwilightMorning/, @schedsch));
  AddToSchedule($A, $AstroTwilightEvening, "AstroTwilightEvening")
    if (grep (/^AstroTwilightEvening/, @schedsch));
  AddToSchedule($A, $CustomTwilightMorning, "CustomTwilightMorning")
    if (grep (/^CustomTwilightMorning/, @schedsch));
  AddToSchedule($A, $CustomTwilightEvening, "CustomTwilightEvening")
    if (grep (/^CustomTwilightEvening/, @schedsch));

  #-- hours of day and night
  my $hoursofsunlight;
  my $hoursofnight;
  if (
      (!defined($sunset) && !defined($sunrise)) ||
      ($sunset !~ m/^\d+/ && $sunrise !~ m/^\d+/)
  ){
    if ($A->{SunAlt} > 0.) {
      $hoursofsunlight = 24.;
      $hoursofnight = 0.;
    } else {
      $hoursofsunlight = 0.;
      $hoursofnight = 24.;
    }
  }
  elsif (!defined($sunset) || $sunset !~ m/^\d+/) {
    $hoursofsunlight = 24. - $sunrise;
    $hoursofnight = 24. - $hoursofsunlight;
  }
  elsif (!defined($sunrise) || $sunrise !~ m/^\d+/) {
    $hoursofsunlight = 24. - $sunset;
    $hoursofnight = 24. - $hoursofsunlight;
  } else {
    my $ss = $sunset;
    $ss += 24.
      if ($sunrise > $sunset);
    $hoursofsunlight = $ss - $sunrise;
    $hoursofnight = 24. - $hoursofsunlight;
  }
  $A->{".SunHrsVisible"}   = $hoursofsunlight;
  $A->{".SunHrsInvisible"} = $hoursofnight;
  $A->{SunHrsVisible}   = HHMM($hoursofsunlight);
  $A->{SunHrsInvisible} = HHMM($hoursofnight);
  
  #-- calculate data for the moon at given time
  my $moonCoor  = MoonPosition($sunCoor->{lon}, $sunCoor->{anomalyMean}, $TDT, $lon, $lat, $radius, $lmst*15.*$DEG);
  $A->{".MoonLon"}      = $moonCoor->{lon}*$RAD;
  $A->{".MoonLat"}      = $moonCoor->{lat}*$RAD;
  $A->{".MoonRa"}       = $moonCoor->{ra} *$RAD/15.;
  $A->{".MoonDec"}      = $moonCoor->{dec}*$RAD;
  $A->{".MoonAz"}       = $moonCoor->{az} *$RAD;
  $A->{".MoonAlt"}      = $moonCoor->{alt}*$RAD + Refraction($moonCoor->{alt});  # including refraction WARNUNG => *RAD ???
  $A->{".MoonDistance"} = $moonCoor->{distance};
  $A->{".MoonDiameter"} = $moonCoor->{diameter}*$RAD*60.; # angular diameter in arc seconds
  $A->{".MoonAge"}      = $moonCoor->{age}*$RAD;
  $A->{".MoonPhaseN"}   = $moonCoor->{phasen};
  $A->{MoonLon}      = _round($A->{".MoonLon"},1);
  $A->{MoonLat}      = _round($A->{".MoonLat"},1);
  $A->{MoonRa}       = _round($A->{".MoonRa"},1);
  $A->{MoonDec}      = _round($A->{".MoonDec"},1);
  $A->{MoonAz}       = _round($A->{".MoonAz"},1);
  $A->{MoonCompassI} = Deg2CP($A->{".MoonAz"});
  $A->{MoonCompass}  = $tt->{Deg2CP($A->{".MoonAz"},0)}[0];
  $A->{MoonCompassS} = $tt->{Deg2CP($A->{".MoonAz"},0)}[1];
  $A->{MoonAlt}      = _round($A->{".MoonAlt"},1);
  $A->{MoonSign}     = $tt->{$moonCoor->{sig}};
  $A->{MoonDistance} = _round($A->{".MoonDistance"},0);
  $A->{MoonDiameter} = _round($A->{".MoonDiameter"},1);
  $A->{MoonAge}      = _round($A->{".MoonAge"},1);
  $A->{MoonPhaseN}   = _round($A->{".MoonPhaseN"},2);
  $A->{MoonPhaseI}   = $moonCoor->{phasei};
  $A->{MoonPhaseS}   = $tt->{$moonCoor->{phases}};
  
  #-- calculate distance from the observer (on the surface of earth) to the center of the moon
  my ($xm,$ym,$zm) = EquPolar2Cart($moonCoor->{ra}, $moonCoor->{dec}, $moonCoor->{distance});
  #Log 1,"  distance=".$moonCoor->{distance}."   test=".sqrt( ($xm)**2 + ($ym)**2 + ($zm)**2 )." $xm  $ym  $zm";
  #Log 1,"  distance=".$radius."   test=".sqrt( ($x)**2 + ($y)**2 + ($z)**2 )." $x  $y  $z";
  $A->{".MoonDistanceObserver"} = sqrt( ($xm-$x)**2 + ($ym-$y)**2 + ($zm-$z)**2 );
  $A->{MoonDistanceObserver}    = _round($A->{".MoonDistanceObserver"},0);
  
  my ($moontransit,$moonrise,$moonset) = MoonRise($JD0, $deltaT, $lon, $lat, $radius, $D->{zonedelta}, 0);
  $A->{".MoonTransit"} = $moontransit;
  $A->{".MoonRise"}    = $moonrise;
  $A->{".MoonSet"}     = $moonset;
  $A->{MoonTransit}    = HHMM($moontransit);
  $A->{MoonRise}       = HHMM($moonrise);
  $A->{MoonSet}        = HHMM($moonset);
  AddToSchedule($A, $moontransit, "MoonTransit")
    if (grep (/^MoonTransit/, @schedsch));
  AddToSchedule($A, $moonrise, "MoonRise")
    if (grep (/^MoonRise/, @schedsch));
  AddToSchedule($A, $moonset, "MoonSet")
    if (grep (/^MoonSet/, @schedsch));

  #-- moon visiblity
  my $moonvisible;
  my $mooninvisible;
  if (
      (!defined($moonset) && !defined($moonrise)) ||
      ($moonset !~ m/^\d+/ && $moonrise !~ m/^\d+/)
  ){
    if ($A->{MoonAlt} >= 0.) {
      $moonvisible = 24.;
      $mooninvisible = 0.;
    } else {
      $moonvisible = 0.;
      $mooninvisible = 24.;
    }
  }
  elsif (!defined($moonset) || $moonset !~ m/^\d+/) {
    $moonvisible = 24. - $moonrise;
    $mooninvisible = 24. - $moonvisible;
  }
  elsif (!defined($moonrise) || $moonrise !~ m/^\d+/) {
    $moonvisible = 24. - $moonset;
    $mooninvisible = 24. - $moonvisible;
  } else {
    my $ss = $moonset;
    $ss += 24.
      if ($moonrise > $moonset);
    $moonvisible = $ss - $moonrise;
    $mooninvisible = 24. - $moonvisible;
  }
  $A->{".MoonHrsVisible"}   = $moonvisible;
  $A->{".MoonHrsInvisible"} = $mooninvisible;
  $A->{MoonHrsVisible}   = HHMM($moonvisible);
  $A->{MoonHrsInvisible} = HHMM($mooninvisible);
  
  #-- fix date
  $A->{ObsDate}             = sprintf("%02d.%02d.%04d",$D->{day},$D->{month},$D->{year});
  $A->{ObsTime}             = sprintf("%02d:%02d:%02d",$D->{hour},$D->{min},$D->{sec});
  $A->{ObsTimeR}            = Arabic2Roman($D->{hour}<=12.?$D->{hour}:$D->{hour}-12.)
                              .($D->{min}==0.?"":":".Arabic2Roman($D->{min}))
                              .($D->{sec}==0.?"":":".Arabic2Roman($D->{sec}));
  $A->{".timestamp"}        = $D->{timestamp};
  $A->{".timeday"}          = $D->{timeday};
  $A->{ObsTimezone}         = $D->{zonedelta};
  $A->{ObsDayofyear}        = $D->{dayofyear};
  $A->{ObsWeekofyear}       = $D->{weekofyear};
  $A->{ObsIsDST}            = $D->{isdst};
  $A->{".isdstnoon"}        = $D->{isdstnoon};
  $A->{ObsIsLeapyear}       = $D->{isly};
  $A->{ObsYearRemainD}      = $D->{yearremdays};
  $A->{ObsMonthRemainD}     = $D->{monthremdays};
  $A->{".ObsYearProgress"}  = $D->{yearprogress};
  $A->{".ObsMonthProgress"} = $D->{monthprogress};
  $A->{ObsYearProgress}     = _round($A->{".ObsYearProgress"}, 2);
  $A->{ObsMonthProgress}    = _round($A->{".ObsMonthProgress"}, 2);
  AddToSchedule($A, 0, "ObsDate ". $A->{ObsDate})
    if (grep (/^ObsDate/, @schedsch));

  #-- Seasonal hours
  $A->{ObsSeasonalHrsDay}   = $dayparts;
  $A->{ObsSeasonalHrsNight} = $nightparts;
  my $daypartlen   = $hoursofsunlight / $dayparts;
  my $nightpartlen = $hoursofnight / $nightparts;
  $A->{".ObsSeasonalHrLenDay"}   = $daypartlen;
  $A->{".ObsSeasonalHrLenNight"} = $nightpartlen;
  $A->{ObsSeasonalHrLenDay}   = HHMMSS($daypartlen);
  $A->{ObsSeasonalHrLenNight} = HHMMSS($nightpartlen);

  my $daypart;
  my $daypartnext;

  #   sunrise and sunset do not occur
  my $daypartTNow = $D->{timeday} + 1./3600.;
  if(
      (!defined($sunrise) || $sunrise !~ m/^\d+/) &&
      (!defined($sunset) || $sunset !~ m/^\d+/)
  ) {
    $daypartlen += $nightpartlen;
    if ($A->{SunAlt} > 0.) {
      $daypart = ceil($daypartTNow/$daypartlen);
    } else {
      $daypart = ($nightparts+1.)*-1. + ceil($daypartTNow/$daypartlen);
    }
  #   sunset does not occur
  } elsif ((!defined($sunset) || $sunset !~ m/^\d+/) && $daypartTNow < $sunrise) {
    $daypart = ($dayparts+1.)*-1. + ceil($daypartTNow/$nightpartlen);
  #   sunrise does not occur
  } elsif((!defined($sunrise) || $sunrise !~ m/^\d+/) && $daypartTNow < $sunset) {
    $daypart = ceil($daypartTNow/$daypartlen);
  #   sunrise or sunset do not occur
  } elsif (
      !defined($sunrise) ||
      $sunrise !~ m/^\d+/ ||
      !defined($sunset) ||
      $sunset !~ m/^\d+/
  ) {
    $daypartlen += $nightpartlen;
    $daypart = ceil($daypartTNow/$daypartlen)
      if ($A->{SunAlt} >= 0.);
    $daypart = ($nightparts+1)*-1 + ceil($daypartTNow/$daypartlen)
      if ($A->{SunAlt} < 0.);
  }
  #   very long days where sunset seems to happen before sunrise
  elsif($sunset < $sunrise) {
    if($D->{timeday} >= $sunrise) {
      $daypart = ceil( ($daypartTNow-$sunrise) / $daypartlen );
    }
    else {
      $daypart = ceil( ($daypartTNow-$sunset) / $nightpartlen );
    }
  }
  #   regular day w/ sunrise and sunset
  elsif ($daypartTNow < $sunrise) {  # after newCalDay but before sunrise
    $daypart = ($nightparts+1)*-1. + ceil( ($daypartTNow+24.-$sunset) / $nightpartlen );
  }
  elsif($daypartTNow < $sunset) {    # after sunrise but before sunset
    $daypart = ceil( ($daypartTNow-$sunrise) / $daypartlen );
  }
  else {                              # after sunset but before newCalDay
    $daypart = ($nightparts+1)*-1. + ceil( ($daypartTNow-$sunset) / $nightpartlen );
  }
  my $daypartdigits = maxNum($dayparts, $nightparts) =~ tr/0-9//;
  my $idp = $nightparts*-1. - 1.;
  while ($idp < -1.) {
    my $id = "-" . sprintf("%0".$daypartdigits."d", ($idp+1.)*-1.);
    my $d = ($nightparts+1-$idp*-1.) * $nightpartlen;
    $d += $sunset if ($sunset ne '---');
    $d -= 24. if ($d >= 24.);
    AddToSchedule($A, $d, "ObsSeasonalHr -" . (($idp+1.)*-1.) )
      if (grep (/^ObsSeasonalHr/, @schedsch));
    if ($D->{timeday} >= $d) {   # if time passed us already, we want it for tomorrow
      if(ref($At)) {
        $d = ($nightparts+1-$idp*-1.) * $At->{".ObsSeasonalHrLenNight"};
        $d += $At->{".SunSet"} if ($At->{".SunSet"} ne '---');
        $d -= 24. if ($d >= 24.);        
      } else {
        $d = "---";
      }
    }
    $A->{".ObsSeasonalHrT$id"} = $d;
    $A->{"ObsSeasonalHrT$id"}  = $d eq '---'?$d: ($d == 0. ? ($daypart < 0. ? '00:00:00' : '---') : HHMMSS($d));
    $idp++;
  }
  $idp = 0;
  while ($idp < $dayparts) {
    my $id = sprintf("%0".$daypartdigits."d", $idp+1.);
    my $d = $idp * $daypartlen;
    $d += $sunrise if ($sunrise ne '---');
    $d -= 24. if ($d >= 24.);
    AddToSchedule($A, $d, "ObsSeasonalHr " . ($idp+1.))
      if (grep (/^ObsSeasonalHr/, @schedsch));
    if ($D->{timeday} >= $d) {   # if time passed us already, we want it for tomorrow
      if(ref($At)) {
        $d = $idp * $At->{".ObsSeasonalHrLenDay"};
        $d += $At->{".SunRise"} if ($At->{".SunRise"} ne '---');
        $d -= 24. if ($d >= 24.);
      } else {
        $d = "---";
      }
    }
    $A->{".ObsSeasonalHrT$id"} = $d;
    $A->{"ObsSeasonalHrT$id"}  = $d eq '---'?$d: ($d == 0. ? ($daypart > 0. ? '00:00:00' : '---') : HHMMSS($d));
    $idp++;
  }
  if ($daypart>0.) {
    $daypartnext  = $daypart * $daypartlen;
    $daypartnext += $sunrise if ($sunrise ne '---');
  } else {
    $daypartnext  = ($nightparts+1-$daypart*-1.) * $nightpartlen;
    $daypartnext += $sunset if ($sunset ne '---');
  }
  $daypartnext -= 24. if ($daypartnext >= 24.);

  $A->{".ObsSeasonalHrTNext"} = $daypartnext;
  $A->{ObsSeasonalHrTNext}    = $daypartnext == 0. ? '00:00:00' : HHMMSS($daypartnext);
  $A->{ObsSeasonalHr}         = $daypart;
  $A->{ObsSeasonalHrR}        = Arabic2Roman($daypart<0?($nightparts+$daypart):$daypart); #FIXME for night

  #-- Daytime
  #--  modern classification
  if ( ($dayparts   == 12. && $nightparts == 12.) ||
       ($dayparts   == 12. && $daypart     > 0. && !$daypartsIsRoman) ||
       ($nightparts == 12. && $daypart     < 0.)
  ) {
    my $dayphase = ($daypart<0.?12.:11.) + $daypart;
    $A->{ObsDaytimeN} = $dayphase;
    $A->{ObsDaytime}  = $tt->{$dayphases[$dayphase]};
  #--  roman classification
  } elsif ( $daypartsIsRoman ||
            ($nightparts == 4. && $daypart < 0.)
  ) {
    my $dayphase = ($daypart<0.?4.:3) + $daypart;
    $A->{ObsDaytimeN} = $dayphase;
    $A->{ObsDaytime}  = ($daypart<0.?'Vigilia ':'Hora ') . Arabic2Roman($daypart<0?$daypart+$nightparts+1.:$daypart);
  #--  unknown classification
  } else {
    $A->{ObsDaytimeN} = "---";
    $A->{ObsDaytime}  = "---";
  }

  #-- check astro season
  my $doj = $A->{ObsDayofyear};

  for( my $i=0;$i<4;$i++){
    my $key = $seasons[$i];
    if(   (($seasonn{$key}[0] < $seasonn{$key}[1]) &&  ($seasonn{$key}[0] <= $doj) && ($seasonn{$key}[1] >= $doj))
       || (($seasonn{$key}[0] > $seasonn{$key}[1]) && (($seasonn{$key}[0] <= $doj) || ($seasonn{$key}[1] >= $doj))) ){
       $A->{ObsSeason}  = $tt->{$key};
       $A->{ObsSeasonN} = $i; 
       last;
    }  
  }

  #-- check meteorological season
  for( my $i=0;$i<4;$i++){
    my $key = $seasons[$i];
    if(   (($seasonmn{$key}[0] < $seasonmn{$key}[1]) &&  ($seasonmn{$key}[0] <= $D->{month}) && ($seasonmn{$key}[1] >= $D->{month}))
       || (($seasonmn{$key}[0] > $seasonmn{$key}[1]) && (($seasonmn{$key}[0] <= $D->{month}) || ($seasonmn{$key}[1] >= $D->{month}))) ){
       $A->{ObsMeteoSeason}  = $tt->{$key};
       $A->{ObsMeteoSeasonN} = $i;
       last;
    }
  }

  #-- check phenological season (for Central Europe only)
  if( $A->{ObsLat} >= 35.0 && $A->{ObsLon} >= -11.0 &&
      $A->{ObsLat} < 71.0 && $A->{ObsLon} < 25.0 )
  {
    my $pheno = 0;

    #      waiting for summer
    if ($D->{month} < 6.0) {
      my $distObs = DistOnEarth(
                      $A->{ObsLat},
                      $A->{ObsLon},
                      $seasonppos{earlyspring}[0],
                      $seasonppos{earlyspring}[1],
                      );
      my $distTotal = DistOnEarth(
                        $seasonppos{earlyspring}[0],
                        $seasonppos{earlyspring}[1],
                        $seasonppos{earlyfall}[0],
                        $seasonppos{earlyfall}[1],
                        );
      my $timeBeg =
        time_str2num($D->{year}.'-'.$earlyspring.' 00:00:00');
      $timeBeg -= 86400.0   #starts 1 day earlier after 28.2. in a leap year
        if (IsLeapYear($D->{year}) &&
            $earlyspring =~ m/^(\d+)-(\d+)$/ &&
            ($1==3 || $2==29)
            );
      my $timeNow = time_str2num(
          $D->{year}.'-'.
          $D->{month}.'-'.
          $D->{day}.
          ' 00:00:00'
          );
      my $progessDays = ($timeNow - $timeBeg) / 86400.0;

      if ($progessDays >= 0.0) {
        $pheno = 1; # spring begins
        my $currDistObs = $distObs - ($progessDays * 37.5);
        if ( $currDistObs <= $distObs * 0.4 ) {
            $pheno = 2; # spring made 40 % of its way to observer
            $currDistObs = $distObs - ($progessDays * 31.0);
            if ( $currDistObs <= 0.0 ) {
                $pheno = 3; # spring reached observer
                my $currDistTotal = $distTotal - ($progessDays * 37.5);
                if ( $currDistTotal <= 0.0 ) {
                    $pheno = 4; # should be early summer already
                }
            }
        }
      }
    }
    #     fairly simple progress during summer
    elsif ($D->{month} < 9.0) {
      $pheno = 4;
      $pheno++ if ($D->{month} >= 7.0);
      $pheno++ if ($D->{month} == 8.0);
    }

    #     waiting for winter
    if ($D->{month} >= 8.0 && $D->{month} < 12.0) {
      my $distObs = DistOnEarth(
                      $A->{ObsLat},
                      $A->{ObsLon},
                      $seasonppos{earlyfall}[0],
                      $seasonppos{earlyfall}[1],
                      );
      my $distTotal = DistOnEarth(
                        $seasonppos{earlyfall}[0],
                        $seasonppos{earlyfall}[1],
                        $seasonppos{earlyspring}[0],
                        $seasonppos{earlyspring}[1],
                        );
      my $timeBeg =
        time_str2num($D->{year}.'-'.$earlyfall.' 00:00:00');
      $timeBeg -= 86400.0   #starts 1 day earlier in a leap year
        if (IsLeapYear($D->{year}));
      my $timeNow = time_str2num(
          $D->{year}.'-'.
          $D->{month}.'-'.
          $D->{day}.
          ' 00:00:00'
          );
      my $progessDays = ($timeNow - $timeBeg) / 86400.0;

      if ($progessDays >= 0.0) {
        $pheno = 7; # fall begins
        my $currDistObs = $distObs - ($progessDays * 35.0);
        if ( $currDistObs <= $distObs * 0.4 ) {
            $pheno = 8; # fall made 40 % of its way to observer
            $currDistObs = $distObs - ($progessDays * 29.5);
            if ( $currDistObs <= 0.0 ) {
                $pheno = 9; # fall reached observer
                my $currDistTotal = $distTotal - ($progessDays * 45.0);
                if ( $currDistTotal <= 0.0 ) {
                    $pheno = 0; # should be winter already
                }
            }
        }
      }
    }

    $A->{ObsPhenoSeason}  = $tt->{$seasonsp[$pheno]};
    $A->{ObsPhenoSeasonN} = $pheno;
  } else {
    Log3 $name,5,"[Astro] Location is out of range to calculate phenological season"
      if (!$dayOffset);
  }

  #-- add info from 2 days before but only +- day will be useful after all
  if (!defined($dayOffset)) {
    $A->{"-2"}  = Compute($hash, -2, $params);  # today-2, has no tomorrow or yesterday
    $A->{"-1"}  = Compute($hash, -1, $params);  # today-1, has tomorrow and yesterday
  }

  #-- reference for yesterday
  my $Ay;
  if (!defined($dayOffset) || $dayOffset == -1. || $dayOffset == 0. || $dayOffset == 1. ) {
    my $t = (!defined($dayOffset)?0.:$dayOffset) - 1.;
    $Ay = \%Astro unless ($t);
    $Ay = $Astro{$t} if ($t && defined($Astro{$t}));
  }

  #-- Change indicators for event day and day before
  $A->{ObsChangedSeason}      = 0 unless ( $A->{ObsChangedSeason} );
  $A->{ObsChangedMeteoSeason} = 0 unless ( $A->{ObsChangedMeteoSeason} );
  $A->{ObsChangedPhenoSeason} = 0 unless ( $A->{ObsChangedPhenoSeason} );
  $A->{ObsChangedSunSign}     = 0 unless ( $A->{ObsChangedSunSign} );
  $A->{ObsChangedMoonSign}    = 0 unless ( $A->{ObsChangedMoonSign} );
  $A->{ObsChangedMoonPhaseS}  = 0 unless ( $A->{ObsChangedMoonPhaseS} );
  $A->{ObsChangedIsDST}       = 0 unless ( $A->{ObsChangedIsDST} );

  #--  Astronomical season is going to change tomorrow
  if (   ref($At)
      && !$At->{ObsChangedSeason}
      && defined( $At->{ObsSeasonN} )
      && $At->{ObsSeasonN} != $A->{ObsSeasonN} )
  {
      $A->{ObsChangedSeason}  = 2;
      $At->{ObsChangedSeason} = 1;
      AddToSchedule( $At, 0, "ObsSeason " . $At->{ObsSeason} )
        if (grep (/^ObsSeason/, @schedsch));
  }
  #--  Astronomical season changed since yesterday
  elsif (ref($Ay)
      && !$Ay->{ObsChangedSeason}
      && defined( $Ay->{ObsSeasonN} )
      && $Ay->{ObsSeasonN} != $A->{ObsSeasonN} )
  {
      $Ay->{ObsChangedSeason} = 2;
      $A->{ObsChangedSeason}  = 1;
      AddToSchedule( $A, 0, "ObsSeason " . $A->{ObsSeason} )
        if (grep (/^ObsSeason/, @schedsch));
  }
  #--  Meteorological season is going to change tomorrow
  if (   ref($At)
      && !$At->{ObsChangedMeteoSeason}
      && defined( $At->{ObsMeteoSeasonN} )
      && $At->{ObsMeteoSeasonN} != $A->{ObsMeteoSeasonN} )
  {
      $A->{ObsChangedMeteoSeason}  = 2;
      $At->{ObsChangedMeteoSeason} = 1;
      AddToSchedule( $At, 0, "ObsMeteoSeason " . $At->{ObsMeteoSeason} )
        if (grep (/^ObsMeteoSeason/, @schedsch));
  }
  #--  Meteorological season changed since yesterday
  elsif (ref($Ay)
      && !$Ay->{ObsChangedMeteoSeason}
      && defined( $Ay->{ObsMeteoSeasonN} )
      && $Ay->{ObsMeteoSeasonN} != $A->{ObsMeteoSeasonN} )
  {
      $Ay->{ObsChangedMeteoSeason} = 2;
      $A->{ObsChangedMeteoSeason}  = 1;
      AddToSchedule( $A, 0, "ObsMeteoSeason " . $A->{ObsMeteoSeason} )
        if (grep (/^ObsMeteoSeason/, @schedsch));
  }
  #--  Phenological season is going to change tomorrow
  if (   ref($At)
      && !$At->{ObsChangedPhenoSeason}
      && defined( $At->{ObsPhenoSeasonN} )
      && $At->{ObsPhenoSeasonN} != $A->{ObsPhenoSeasonN} )
  {
      $A->{ObsChangedPhenoSeason}  = 2;
      $At->{ObsChangedPhenoSeason} = 1;
      AddToSchedule( $At, 0, "ObsPhenoSeason " . $At->{ObsPhenoSeason} )
        if (grep (/^ObsPhenoSeason/, @schedsch));
  }
  #--  Phenological season changed since yesterday
  elsif (ref($Ay)
      && !$Ay->{ObsChangedPhenoSeason}
      && defined( $Ay->{ObsPhenoSeasonN} )
      && $Ay->{ObsPhenoSeasonN} != $A->{ObsPhenoSeasonN} )
  {
      $Ay->{ObsChangedPhenoSeason} = 2;
      $A->{ObsChangedPhenoSeason}  = 1;
      AddToSchedule( $A, 0, "ObsPhenoSeason " . $A->{ObsPhenoSeason} )
        if (grep (/^ObsPhenoSeason/, @schedsch));
  }
  #--  SunSign is going to change tomorrow
  if (   ref($At)
      && !$At->{ObsChangedSunSign}
      && defined( $At->{SunSign} )
      && $At->{SunSign} ne $A->{SunSign} )
  {
      $A->{ObsChangedSunSign}  = 2;
      $At->{ObsChangedSunSign} = 1;
      AddToSchedule( $At, 0, "SunSign " . $At->{SunSign} )
        if (grep (/^SunSign/, @schedsch));
  }
  #--  SunSign changed since yesterday
  elsif (ref($Ay)
      && !$Ay->{ObsChangedSunSign}
      && defined( $Ay->{SunSign} )
      && $Ay->{SunSign} ne $A->{SunSign} )
  {
      $Ay->{ObsChangedSunSign} = 2;
      $A->{ObsChangedSunSign}  = 1;
      AddToSchedule( $A, 0, "SunSign " . $A->{SunSign} )
        if (grep (/^SunSign/, @schedsch));
  }
  #--  MoonSign is going to change tomorrow
  if (   ref($At)
      && !$At->{ObsChangedMoonSign}
      && defined( $At->{MoonSign} )
      && $At->{MoonSign} ne $A->{MoonSign} )
  {
      $A->{ObsChangedMoonSign}  = 2;
      $At->{ObsChangedMoonSign} = 1;
      AddToSchedule( $At, 0, "MoonSign " . $At->{MoonSign} )
        if (grep (/^MoonSign/, @schedsch));
  }
  #--  MoonSign changed since yesterday
  elsif (ref($Ay)
      && !$Ay->{ObsChangedMoonSign}
      && defined( $Ay->{MoonSign} )
      && $Ay->{MoonSign} ne $A->{MoonSign} )
  {
      $Ay->{ObsChangedMoonSign} = 2;
      $A->{ObsChangedMoonSign}  = 1;
      AddToSchedule( $A, 0, "MoonSign " . $A->{MoonSign} )
        if (grep (/^MoonSign/, @schedsch));
  }
  #--  MoonPhase is going to change tomorrow
  if (   ref($At)
      && !$At->{ObsChangedMoonPhaseS}
      && defined( $At->{MoonPhaseS} )
      && $At->{MoonPhaseI} != $A->{MoonPhaseI} )
  {
      $A->{ObsChangedMoonPhaseS}  = 2;
      $At->{ObsChangedMoonPhaseS} = 1;
      AddToSchedule( $At, 0, "MoonPhaseS " . $At->{MoonPhaseS} )
        if (grep (/^MoonPhaseS/, @schedsch));
  }
  #--  MoonPhase changed since yesterday
  elsif (ref($Ay)
      && !$Ay->{ObsChangedMoonPhaseS}
      && defined( $Ay->{MoonPhaseS} )
      && $Ay->{MoonPhaseI} != $A->{MoonPhaseI} )
  {
      $Ay->{ObsChangedMoonPhaseS} = 2;
      $A->{ObsChangedMoonPhaseS}  = 1;
      AddToSchedule( $A, 0, "MoonPhaseS " . $A->{MoonPhaseS} )
        if (grep (/^MoonPhaseS/, @schedsch));
  }
  #--  DST is going to change tomorrow
  if (   ref($At)
      && !$At->{ObsChangedIsDST}
      && defined( $At->{ObsIsDST} )
      && $At->{".isdstnoon"} != $A->{".isdstnoon"} )
  {
      $A->{ObsChangedIsDST}  = 2;
      $At->{ObsChangedIsDST} = 1;
      AddToSchedule( $At, 0, "ObsIsDST " . $At->{ObsIsDST} )
        if (grep (/^ObsIsDST/, @schedsch));
  }
  #--  DST is going to change somewhere today
  elsif (ref($Ay)
      && !$Ay->{ObsChangedIsDST}
      && defined( $Ay->{ObsIsDST} )
      && $Ay->{".isdstnoon"} != $A->{".isdstnoon"} )
  {
      $Ay->{ObsChangedIsDST} = 2;
      $A->{ObsChangedIsDST}  = 1;
      AddToSchedule( $A, 0, "ObsIsDST " . $A->{ObsIsDST} )
        if (grep (/^ObsIsDST/, @schedsch));
  }

  #-- schedule
  if ( defined( $A->{".schedule"} ) ) {

      #-- future of tomorrow
      if ( ref($At) ) {
          foreach my $e ( sort { $a <=> $b } keys %{ $At->{".schedule"} } ) {
              foreach ( @{ $At->{".schedule"}{$e} } ) {
                AddToSchedule($A, 24, $_);
              }
              last;    # only add first event of next day
          }
      }

      foreach my $e ( sort { $a <=> $b } keys %{ $A->{".schedule"} } ) {

          #-- past of today
          if ( $e <= $daypartTNow ) {
              $A->{".ObsSchedLastT"} = $e == 24. ? 0 : $e;
              $A->{ObsSchedLastT} =
                $e == 0. || $e == 24. ? '00:00:00' : HHMMSS($e);
              $A->{ObsSchedLast} = join( ", ", @{ $A->{".schedule"}{$e} } );
              $A->{ObsSchedRecent} =
                join( ", ", reverse @{ $A->{".schedule"}{$e} } )
                . (
                  defined( $A->{ObsSchedRecent} )
                  ? ", " . $A->{ObsSchedRecent}
                  : ""
                );
          }

          #-- future of today
          else {
              unless ( defined( $A->{".ObsSchedNextT"} ) ) {
                  $A->{".ObsSchedNextT"} = $e == 24. ? 0 : $e;
                  $A->{ObsSchedNextT} =
                    $e == 0. || $e == 24. ? '00:00:00' : HHMMSS($e);
                  $A->{ObsSchedNext} = join( ", ", @{ $A->{".schedule"}{$e} } );
              }
              $A->{ObsSchedUpcoming} .= ", "
                if ( defined( $A->{ObsSchedUpcoming} ) );
              $A->{ObsSchedUpcoming} .= join( ", ", @{ $A->{".schedule"}{$e} } );
          }
      }
  } else {
    $A->{ObsSchedLast}     = "---";
    $A->{ObsSchedLastT}    = "---";
    $A->{ObsSchedNext}     = "---";
    $A->{ObsSchedNextT}    = "---";
    $A->{ObsSchedRecent}   = "---";
    $A->{ObsSchedUpcoming} = "---";
  }

  return $A
    if ($dayOffset);
  return( undef );
};

########################################################################################################
#
# AddToSchedule - adds a time and description to the daily schedule
#
########################################################################################################
sub AddToSchedule {
    my ( $h, $e, $n ) = @_;
    push @{ $h->{".schedule"}{$e} }, $n
      if ( defined($e) && $e =~ m/^\d+(?:\.\d+)?$/ );
}

########################################################################################################
#
# Moonwidget - SVG picture of the moon 
#
#  Parameter hash = hash of the bus master a = argument array
#
########################################################################################################

sub Moonwidget($){
  my ($arg) = @_;
  my $name = $FW_webArgs{name};
  $name    =~ s/'//g if ($name);
  my $hash = $name && $name ne "" && defined($defs{$name}) ? $defs{$name} : ();
  
  my $mooncolor = 'rgb(255,220,100)';
  my $moonshadow = 'rgb(70,70,100)';

  $mooncolor = $FW_webArgs{mooncolor} 
    if ($FW_webArgs{mooncolor} );
  $moonshadow = $FW_webArgs{moonshadow}
    if ($FW_webArgs{moonshadow} );
    
  my @size = split('x', ($FW_webArgs{size} ? $FW_webArgs{size}  : '400x400'));
  
  $FW_RETTYPE = "image/svg+xml";
  $FW_RET="";
  FW_pO '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 800" width="'.$size[0].'px" height="'.$size[1].'px">';
  my $ma = Get($hash,("","text","MoonAge"));
  my $mb = Get($hash,("","text","MoonPhaseS"));

  my ($radius,$axis,$dir,$start,$middle);
  $radius = 250;
  $axis   = sin(($ma+90)*$DEG)*$radius;
  $axis   = -$axis
    if ($axis < 0);
    
  if( (0.0 <= $ma && $ma <= 90) || (270.0 < $ma && $ma <= 360.0) ){
    $dir = 1;
  }else{
    $dir = 0;
  }
  if( 0.0 < $ma && $ma <= 180 ){
    $start  = $radius;
    $middle = -$radius;
  }else{
    $start  = -$radius;
    $middle = $radius;
  }
 
  FW_pO '<g transform="translate(400,400) scale(-1,1)">';
  FW_pO '<circle cx="0" cy="0" r="250" fill="'.$moonshadow.'"/>';
  FW_pO '<path d="M 0 '.$start.' A '.$axis.' '.$radius.' 0 0 '.$dir.' 0 '.$middle.' A '.$radius.' '.$radius.' 0 0 0 0 '.$start.' Z" fill="'.$mooncolor.'"/>'; 
  FW_pO '</g>';
  #FW_pO '<text x="100" y="710" style="font-family:Helvetica;font-size:60px;font-weight:bold" fill="black">'.$mb.'</text>';
  FW_pO '</svg>';
  return ($FW_RETTYPE, $FW_RET); 
}	         

########################################################################################################
#
# Update - Update readings 
#
#  Parameter hash = hash of the bus master a = argument array
#
########################################################################################################

sub Update($@) {
  my ($hash) = @_;
  
  my $name     = $hash->{NAME};
  RemoveInternalTimer($hash);
  delete $hash->{NEXTUPDATE};

  return undef if (IsDisabled($name));

  my $now = gettimeofday();    # conserve timestamp before recomputing

  SetTime();
  Compute($hash);

  my @next;

  #-- add regular update interval time
  push @next, $now + $hash->{INTERVAL}
    if ( defined( $hash->{INTERVAL} ) && $hash->{INTERVAL} > 0 );

  #-- add event times
  foreach my $comp (
      defined( $hash->{RECOMPUTEAT} ) ? split( ',', $hash->{RECOMPUTEAT} ) : () )
  {
      if ( $comp eq 'NewDay' ) {
          push @next,
            timelocal( 0, 0, 0, ( localtime( $now + 86400. ) )[ 3, 4, 5 ] );
          next;
      }
      my $k = ".$comp";
      $k = '.ObsSeasonalHrTNext' if ( $comp eq 'SeasonalHr' );
      next unless ( defined( $Astro{$k} ) && $Astro{$k} =~ /^\d+(?:\.\d+)?$/ );
      my $t =
        timelocal( 0, 0, 0, ( localtime($now) )[ 3, 4, 5 ] ) + $Astro{$k} * 3600.;
      $t += 86400. if ( $t < $now );    # that is for tomorrow
      push @next, $t;
  }

  #-- set timer for next update
  if (@next) {
      my $n = minNum( $next[0], @next );
      $hash->{NEXTUPDATE} = FmtDateTime($n);
      InternalTimer( $n, "FHEM::Astro::Update", $hash, 1 );
  }

  readingsBeginUpdate($hash);
  foreach my $key (keys %Astro){   
    next if(ref($Astro{$key}));
    readingsBulkUpdateIfChanged($hash,$key,$Astro{$key});
  }
  readingsEndUpdate($hash,1); 
  readingsSingleUpdate($hash,"state","Updated",1);
}

########################################################################################################
#
# Set - Implements SetFn function 
#
#  Parameter hash = hash of the bus master a = argument array
#
########################################################################################################

sub Set($@) {
    my ($hash,$a,$h) = @_;

    my $name = shift @$a;

    if ( $a->[0] eq "update" ) {
        return "[FHEM::Astro::Set] $name is disabled" if ( IsDisabled($name) );
        RemoveInternalTimer($hash);
        InternalTimer( gettimeofday() + 1, "FHEM::Astro::Update", $hash, 1 );
    }
    else {
        return
          "[FHEM::Astro::Set] $name with unknown argument $a->[0], choose one of "
          . join( " ",
            map { defined( $sets{$_} ) ? "$_:$sets{$_}" : $_ }
            sort keys %sets );
    }

    return "";
}

########################################################################################################
#
# Get - Implements GetFn function 
#
#  Parameter hash = hash of the bus master a = argument array
#
########################################################################################################

sub Get($@) {
  my ($hash,$a,$h,@a) = @_;
  my $name = "#APIcall";

  #-- backwards compatibility for non-parseParams requests
  if (!ref($a)) {
    $hash = exists($defs{$hash}) ? $defs{$hash} : ()
      if ($hash && !ref($hash));
    if (defined($hash->{NAME})) {
      $name = $hash->{NAME};
    } else {
      $hash->{NAME} = $name;
    }
    unshift @a, $h;
    $h = undef;
    $a = \@a;
  }
  else {
    $name = shift @$a;
  }

  my $wantsreading = 0;
  my $dayOffset = 0;

  #-- fill %Astro if it is still empty after restart
  Compute($hash, undef, $h) if (scalar keys %Astro == 0);

  #-- second parameter may be a reading
  if( (int(@$a)>1) && exists($Astro{$a->[1]}) && !ref($Astro{$a->[1]})) {
    $wantsreading = 1;
  }

  #-- last parameter may be indicating day offset
  if(
    (int(@$a)>4+$wantsreading && $a->[4+$wantsreading] =~ /^\+?([-+]\d+|yesterday|tomorrow)$/i) ||
    (int(@$a)>3+$wantsreading && $a->[3+$wantsreading] =~ /^\+?([-+]\d+|yesterday|tomorrow)$/i) ||
    (int(@$a)>2+$wantsreading && $a->[2+$wantsreading] =~ /^\+?([-+]\d+|yesterday|tomorrow)$/i) ||
    (int(@$a)>1+$wantsreading && $a->[1+$wantsreading] =~ /^\+?([-+]\d+|yesterday|tomorrow)$/i)
  ){
    $dayOffset = $1;
    pop @$a;
    $dayOffset = -1 if (lc($dayOffset) eq "yesterday");
    $dayOffset = 1  if (lc($dayOffset) eq "tomorrow");
  }

  if( int(@$a) > (1+$wantsreading) ) {
    my $str = (int(@$a) == (3+$wantsreading)) ? $a->[1+$wantsreading]." ".$a->[2+$wantsreading] : $a->[1+$wantsreading];
    if( $str =~ /^(\d{2}):(\d{2})(?::(\d{2}))?|(?:(\d{4})-(\d{2})-(\d{2}))(?:\D+(\d{2}):(\d{2})(?::(\d{2}))?)?$/){
      SetTime(
          timelocal(
              defined($3) ? $3 : (defined($9) ? $9 : 0),
              defined($2) ? $2 : (defined($8) ? $8 : 0),
              defined($1) ? $1 : (defined($7) ? $7 : 12),
              (defined($4)? ($6,$5-1,$4) : (localtime(gettimeofday()))[3,4,5])
          ) + ( $dayOffset * 86400. )
        )
    }else{
      return "[FHEM::Astro::Get] $name has improper time specification $str, use YYYY-MM-DD [HH:MM:SS] [-1|yesterday|+1|tomorrow]";
    }
  }else{
    SetTime(gettimeofday + ($dayOffset * 86400.));
  }

  if( $a->[0] eq "version") {
    return $VERSION;
    
  }elsif( $a->[0] eq "json") {
    Compute($hash, undef, $h);
    #-- beautify JSON at cost of performance only when debugging
    if (ref($json) && AttrVal($name,"verbose",AttrVal("global","verbose",3)) > 3.) {
      $json->canonical;
      $json->pretty;
    }
    if( $wantsreading==1 ){
      return $json->encode($Astro{$a->[1]}) if (ref($json));
      return toJSON($Astro{$a->[1]});
    }else{
      # only publish today
      delete $Astro{2};
      delete $Astro{1};
      delete $Astro{"-2"};
      delete $Astro{"-1"};
      return $json->encode(\%Astro) if (ref($json));
      return toJSON(\%Astro);
    }
    
  }elsif( $a->[0] eq "text") {
  
    Compute($hash, undef, $h);
    if( $wantsreading==1 ){
      return $Astro{$a->[1]};
    }else{
      my $ret=sprintf("%s %s %s",$tt->{"date"},$Astro{ObsDate},$Astro{ObsTime});
      $ret .= " (".$tt->{"dst"}.")" if($Astro{ObsIsDST}==1);
      $ret .= sprintf(", %s %2d\n",$tt->{"timezone"},$Astro{ObsTimezone});
      $ret .= sprintf("%s ".($Astro{ObsSeasonalHrsDay}>9||$Astro{ObsSeasonalHrsNight}>9?"%3d":"%2d"),
        (($Astro{ObsSeasonalHrsDay}==12 && $Astro{ObsSeasonalHr} > 0.) ||
          $Astro{ObsSeasonalHrsNight}==12 && $Astro{ObsSeasonalHr} < 0. ?
          $tt->{"temporalhour"}:$tt->{"seasonalhour"}),
        $Astro{ObsSeasonalHr});
      $ret .= sprintf("%s%s\n",( $Astro{ObsDaytime} ne "---" ? (", ".$tt->{"dayphase"},": ".$Astro{ObsDaytime}) : ("","") ));
      $ret .= sprintf("%s %.2f %s, %3d %s, %3d %s",$tt->{"jdate"},$Astro{ObsJD},$tt->{"days"},
        $Astro{ObsDayofyear},$tt->{"dayofyear"},$Astro{ObsYearRemainD},
        ($Astro{ObsYearRemainD}==1?$tt->{"dayremaining"}:$tt->{"daysremaining"}));
      $ret .= ($Astro{ObsIsLeapyear}==1 ? sprintf(", %s\n",$tt->{"leapyear"}):"\n");
      $ret .= sprintf("%s: %s\n",$tt->{"season"},$Astro{ObsSeason});
      $ret .= sprintf("%s: %s\n",$tt->{"metseason"},$Astro{ObsMeteoSeason});
      $ret .= sprintf("%s: %s\n",$tt->{"phenseason"},$Astro{ObsPhenoSeason}) if(exists($Astro{ObsPhenoSeason}));
      $ret .= sprintf("%s %.5f° %s, %.5f° %s, %.0fm %s\n",$tt->{"coord"},$Astro{ObsLat},$tt->{"latitude"},
        $Astro{ObsLon},$tt->{"longitude"},$Astro{ObsAlt},$tt->{"altitude"});
      $ret .= sprintf("%s %s\n\n",$tt->{"lmst"},$Astro{ObsLMST});
      $ret .= "\n".$tt->{"sun"}."\n";
      $ret .= sprintf("%s %s   %s %s   %s %s\n",
        $tt->{"rise"},$Astro{SunRise},
        $tt->{"set"},$Astro{SunSet},
        $tt->{"transit"},$Astro{SunTransit});
      $ret .= sprintf("%s %s   %s %s\n",$tt->{"hoursofsunlight"},$Astro{SunHrsVisible},$tt->{"hoursofnight"},$Astro{SunHrsInvisible});
      $ret .= sprintf("%s %s  -  %s\n",$tt->{"twilightcivil"},$Astro{CivilTwilightMorning},$Astro{CivilTwilightEvening});
      $ret .= sprintf("%s %s  -  %s\n",$tt->{"twilightnautic"},$Astro{NauticTwilightMorning},$Astro{NauticTwilightEvening});
      $ret .= sprintf("%s %s  -  %s\n",$tt->{"twilightastro"},$Astro{AstroTwilightMorning},$Astro{AstroTwilightEvening});
      $ret .= sprintf("%s: %.0fkm %s (%.0fkm %s)\n",
        $tt->{"distance"},$Astro{SunDistance},
        $tt->{"toce"},$Astro{SunDistanceObserver},$tt->{"toobs"});
      $ret .= sprintf("%s:  %s %2.1f°, %s %2.2fh, %s %2.1f°; %s %2.1f°, %s %2.1f°\n",
        $tt->{"position"},$tt->{"lonecl"},$Astro{SunLon},$tt->{"ra"},
        $Astro{SunRa},$tt->{"dec"},$Astro{SunDec},$tt->{"az"},$Astro{SunAz},$tt->{"alt"},$Astro{SunAlt});
      $ret .= sprintf("%s %2.1f', %s %s\n\n",$tt->{"diameter"},$Astro{SunDiameter},$tt->{"sign"},$Astro{SunSign});
      $ret .= "\n".$tt->{"moon"}."\n";
      $ret .= sprintf("%s %s   %s %s   %s %s\n",
        $tt->{"rise"},$Astro{MoonRise},
        $tt->{"set"},$Astro{MoonSet},
        $tt->{"transit"},$Astro{MoonTransit});
      $ret .= sprintf("%s %s\n",$tt->{"hoursofvisibility"},$Astro{MoonHrsVisible});
      $ret .= sprintf("%s: %.0fkm %s (%.0fkm %s)\n",
        $tt->{"distance"},$Astro{MoonDistance},
        $tt->{"toce"},$Astro{MoonDistanceObserver},$tt->{"toobs"});
      $ret .= sprintf("%s:  %s %2.1f°, %s %2.1f°; %s %2.2fh, %s %2.1f°; %s %2.1f°, %s %2.1f°\n",
        $tt->{"position"},$tt->{"lonecl"},$Astro{MoonLon},$tt->{"latecl"},$Astro{MoonLat},$tt->{"ra"},
        $Astro{MoonRa},$tt->{"dec"},$Astro{MoonDec},$tt->{"az"},$Astro{MoonAz},$tt->{"alt"},$Astro{MoonAlt});
      $ret .= sprintf("%s %2.1f', %s %2.1f°, %s %1.2f = %s, %s %s\n",
        $tt->{"diameter"},$Astro{MoonDiameter},
        $tt->{"age"},$Astro{MoonAge},
        $tt->{"phase"},$Astro{MoonPhaseN},$Astro{MoonPhaseS},
        $tt->{"sign"},$Astro{MoonSign});

     return $ret;
    }
  }else {
    return "[FHEM::Astro::Get] $name with unknown argument $a->[0], choose one of ". 
    join(" ", map { defined($gets{$_})?"$_:$gets{$_}":$_ } sort keys %gets);
  }
}

1;

=pod
=encoding utf8
=item helper
=item summary collection of various routines for astronomical data
=item summary_DE Sammlung verschiedener Routinen für astronomische Daten
=begin html

   <a name="Astro"></a>
        <h3>Astro</h3>
        <ul>
        <p> FHEM module with a collection of various routines for astronomical data</p>
        <a name="Astrodefine"></a>
        <h4>Define</h4>
        <p>
            <code>define &lt;name&gt; Astro</code>
            <br />Defines the Astro device (only one is needed per FHEM installation). </p>
        <p>
        Readings with prefix <i>Sun</i> refer to the sun, with prefix <i>Moon</i> refer to the moon.
        The suffixes for these readings are:
        <ul>
        <li><i>Age</i> = angle (in degrees) of body along its track</li>
        <li><i>Az,Alt</i> = azimuth and altitude angle (in degrees) of body above horizon</li>
        <li><i>Compass,CompassI,CompassS</i> = azimuth as point of the compass</li>
        <li><i>Dec,Ra</i> = declination (in degrees) and right ascension (in HH:MM) of body position</li>
        <li><i>HrsVisible,HrsInvisible</i> = Hours of visiblity and invisiblity of the body</li>
        <li><i>Lat,Lon</i> = latitude and longituds (in degrees) of body position</li>
        <li><i>Diameter</i> = virtual diameter (in arc minutes) of body</li>
        <li><i>Distance,DistanceObserver</i> = distance (in km) of body to center of earth or to observer</li>
        <li><i>PhaseN,PhaseS</i> = Numerical and string value for phase of body</li>
	      <li><i>Sign</i> = Circadian sign for body along its track</li>
	      <li><i>Rise,Transit,Set</i> = times (in HH:MM) for rise and set as well as for highest position of body</li>
        </ul>
        <p>
        Readings with prefix <i>Obs</i> refer to the observer.
        In addition to some of the suffixes gives above, the following may occur:
        <ul>
        <li><i>Date,Dayofyear,Weekofyear,YearRemainD,YearProgress,ObsMonthRemainD,ObsMonthProgress</i> = date</li>
        <li><i>YearRemainD,YearProgress,MonthRemainD,MonthProgress</i> = progress throughout month and year</li>
        <li><i>Daytime,DaytimeN</i> = String and numerical (0..23) value of relative daytime/nighttime, based on SeasonalHr. Counting begins after sunset.</li>
        <li><i>JD</i> = Julian date</li>
        <li><i>Changed*</i> = Change indicators. Value is 2 the day before the change is going to take place, 1 at the day the change has occured.</li>
        <li><i>Season,SeasonN</i> = String and numerical (0..3) value of astrological season</li>
        <li><i>MeteoSeason,MeteoSeasonN</i> = String and numerical (0..3) value of meteorological season</li>
        <li><i>PhenoSeason,PhenoSeasonN</i> = String and numerical (0..9) value of phenological season</li>
        <li><i>SchedLast,SchedLastT,SchedNext,SchedNextT</i> = Last/current event and next event</li>
        <li><i>SchedRecent,SchedUpcoming</i> = List of recent and upcoming events today. SchedUpcoming includes the very first events at 00:00:00 of the next day at the end.</li>
        <li><i>SeasonalHrLenDay,SeasonalHrLenNight</i> = Length of a single seasonal hour during sunlight and nighttime as defined by SeasonalHrsDay and SeasonalHrsNight</li>
        <li><i>SeasonalHr,ObsSeasonalHrR,SeasonalHrsDay,SeasonalHrsNight</i> = Current and total seasonal hours of a full day. Values for SeasonalHr will be between -12 and 12 (actual range depends on the definition of SeasonalHrsDay and SeasonalHrsNight), but will never be 0. Positive values will occur between sunrise and sunset while negative values will occur during nighttime. Numbers will always be counting upwards, for example from 1 to 12 during daytime and from -12 to -1 during nighttime. That way switching between daytime&lt;&gt;nighttime means only to change the algebraic sign from -1 to 1 and 12 to -12 respectively.</li>
        <li><i>SeasonalHrTNext,SeasonalHrT*</i> Calculated times for the beginning of the respective seasonal hour. SeasonalHrTNext will be set for the next upcoming seasonal hour. Hours that are in the past for today will actually show times for the next calendar day.</li>
        <li><i>Time,TimeR,Timezone</i> obvious meaning</li>
        <li><i>IsDST</i> = 1 if running on daylight savings time, 0 otherwise</li>
        <li><i>IsLeapyear</i> = 1 if the year is a leap year, 0 otherwise</li>
        <li><i>GMST,LMST</i> = Greenwich and Local Mean Sidereal Time (in HH:MM)</li>
	    </ul>
	    <p>
	    An SVG image of the current moon phase may be obtained under the link 
	    <code>&lt;ip address of fhem&gt;/fhem/Astro_moonwidget?name='&lt;device name&gt;'</code>.
	    Optional web parameters are <code>[&amp;size='&lt;width&gt;x&lt;height&gt;'][&amp;mooncolor=&lt;color&gt;][&amp;moonshadow=&lt;color&gt;]</code>
	    <p>
        Notes: <ul>
        <li>Calculations are only valid between the years 1900 and 2100</li>
        <li>Attention: Timezone is taken from the local Perl settings, NOT automatically defined for a location</li>
        <li>This module uses the global attribute <code>language</code> to determine its output data<br/>
         (default: EN=english). For German output, set <code>attr global language DE</code>.<br/>
         If a local attribute was set for language it will take precedence.</li>
        <li>The time zone is determined automatically from the local settings of the <br/>
        operating system. If geocordinates from a different time zone are used, the results are<br/>
        not corrected automatically.</li>
        <li>The phenological season will only be estimated if the observers position is located in Central Europe.
        Due to its definition, a phenological season cannot be strictly calculated. It is not supposed to be 100%
        accurate and therefore not to be used for agrarian purposes but should be close enough for other
        home automations like heating, cooling, shading, etc.</li>
        <li>As the relative daytime is based on temporal hours, it can only be emerged if seasonalHrs is set to 12
        (which is the default setting).</li>
        <li>Some definitions determining the observer position are used<br/>
        from the global device, i.e.<br/>
        <ul>
        <code>attr global longitude &lt;value&gt;</code><br/>
        <code>attr global latitude &lt;value&gt;</code><br/>
        <code>attr global altitude &lt;value&gt;</code> (in m above sea level)
        </ul>
        These definitions are only used when there are no corresponding local attribute settings.
        </li>
        <li>
        It is not necessary to define an Astro device to use the data provided by this module.<br/>
        To use its data in any other module, you just need to put <code>require "95_Astro.pm";</code> <br/>
        at the start of your own code, and then may call, for example, the function<br/> 
        <ul><code>Astro_Get( SOME_HASH_REFERENCE,"dummy","text", "SunRise","2019-12-24");</code></ul>
        to acquire the sunrise on Christmas Eve 2019. The hash reference may also be undefined or an existing device name of any type. Note that device attributes of the respective device will be respected as long as their name matches those mentioned for an Astro device.
        attribute=value pairs may be added in text format to enforce
        settings like language that would otherwise be defined by a real device.</li>
        </ul>
        <a name="Astroset"></a>
        <h4>Set</h4>
        <ul>
            <li><a name="Astro_update"></a>
                <code>set &lt;name&gt; update</code>
                <br />trigger to recompute values immediately.</li>
        </ul>
        <a name="Astroget"></a>
        <h4>Get</h4>
        Attention: Get-calls are NOT written into the readings of the device. Readings change only through periodic updates.<br/>
        <ul>
            <li><a name="Astro_json"></a>
                <code>get &lt;name&gt; json [&lt;reading&gt;] [-1|yesterday|+1|tomorrow]</code><br/>
                <code>get &lt;name&gt; json [&lt;reading&gt;] YYYY-MM-DD [-1|yesterday|+1|tomorrow]</code><br/>
                <code>get &lt;name&gt; json [&lt;reading&gt;] HH:MM[:SS] [-1|yesterday|+1|tomorrow]</code><br/>
                <code>get &lt;name&gt; json [&lt;reading&gt;] YYYY-MM-DD HH:MM[:SS] [-1|yesterday|+1|tomorrow]</code>
                <br />returns the complete set of an individual reading of astronomical data either for the current time, or for a day and time given in the argument. <code>yesterday</code>, <code>tomorrow</code> or any other integer number may be given at the end to get data relative to the given day and time.</li>
            <li><a name="Astro_text"></a>
                <code>get &lt;name&gt; text [&lt;reading&gt;] [-1|yesterday|+1|tomorrow]</code><br/>
                <code>get &lt;name&gt; text [&lt;reading&gt;] YYYY-MM-DD [-1|yesterday|+1|tomorrow]</code><br/>
                <code>get &lt;name&gt; text [&lt;reading&gt;] HH:MM[:SS] [-1|yesterday|+1|tomorrow]</code><br/>
                <code>get &lt;name&gt; text [&lt;reading&gt;] YYYY-MM-DD HH:MM[:SS] [-1|yesterday|+1|tomorrow]</code>
                <br />returns the complete set of an individual reading of astronomical data either for the current time, or for a day and time given in the argument. <code>yesterday</code>, <code>tomorrow</code> or any other integer number may be given at the end to get data relative to the given day and time.</li>            
            <li><a name="Astro_version"></a>
                <code>get &lt;name&gt; version</code>
                <br />Display the version of the module</li>             
        </ul>
        <a name="Astroattr"></a>
        <h4>Attributes</h4>
        <ul>
            <li><a name="Astro_earlyfall"></a>
                <code>&lt;earlyfall&gt;</code>
                <br />The early beginning of fall will set a marker to calculate all following phenological seasons until winter time.
                      This defaults to 08-20 to begin early fall on August 20th.</li>
            <li><a name="Astro_earlyspring"></a>
                <code>&lt;earlyspring&gt;</code>
                <br />The early beginning of spring will set a marker to calculate all following phenological seasons until summer time.
                      This defaults to 02-22 to begin early spring on February 22nd.</li>
            <li><a name="Astro_interval"></a>
                <code>&lt;interval&gt;</code>
                <br />Update interval in seconds. The default is 3600 seconds, a value of 0 disables the periodic update.</li>
            <li><a name="Astro_language"></a>
                <code>&lt;language&gt;</code>
                <br />A language may be set to overwrite global attribute settings.</li>
            <li><a name="Astro_recomputeAt"></a>
                <code>&lt;recomputeAt&gt;</code>
                <br />Enforce recomputing values at specific event times, independant from update interval. This attribute contains a list of one or many of the following values:<br />
                      <ul>
                      <li><i>MoonRise,MoonSet,MoonTransit</i> = for moon rise, set, and transit</li>
                      <li><i>NewDay</i> = for 00:00:00 hours of the next calendar day (some people may say midnight)</li>
                      <li><i>SeasonalHr</i> = for the beginning of every seasonal hour</li>
                      <li><i>SunRise,SunSet,SunTransit</i> = for sun rise, set, and transit</li>
                      <li><i>*TwilightEvening,*TwilightMorning</i> = for the respective twilight stage begin</li>
                      </ul></li>
            <li><a name="Astro_schedule"></a>
                <code>&lt;schedule&gt;</code>
                <br />Define which events will be part of the schedule list. A full schedule will be generated if this attribute was not specified. This also controls the value of ObsSched* readings.</li>
            <li><a name="Astro_seasonalHrs"></a>
                <code>&lt;seasonalHrs&gt;</code>
                <br />Number of total seasonal hours to divide daylight time and nighttime into (day parts).
                      It controls the calculation of reading ObsSeasonalHr throughout a full day.
                      The default value is 12 which corresponds to the definition of temporal hours.
                      In case the amount of hours during nighttime shall be different, they can be defined as
                      <code>&lt;dayHours&gt;:&lt;nightHours&gt;</code>. A value of '4' will enforce historic roman mode with implicit 12:4 settings but the Daytime to be reflected in latin notation. Defining a value of 12:4 directly will still show regular daytimes during daytime. Defining *:4 nighttime parts will always calculate Daytime in latin notation during nighttime, independant from daytime settings.</li>
            <li>Some definitions determining the observer position:<br/>
                <ul>
                <code>attr  &lt;name&gt;  longitude &lt;value&gt;</code><br/>
                <code>attr  &lt;name&gt;  latitude &lt;value&gt;</code><br/>
                <code>attr  &lt;name&gt;  altitude &lt;value&gt;</code> (in m above sea level)<br/>
                <code>attr  &lt;name&gt;  horizon &lt;value&gt;</code> custom horizon angle in degrees, default 0. Different values for morning/evening may be set as <code>&lt;morning&gt;:&lt;evening&gt;</code>
                </ul>
                These definitions take precedence over global attribute settings.</li>
            <li><a name="Astro_disable"></a>
                <code>&lt;disable&gt;</code>
                <br />When set, this will completely disable any device update.</li>
            <li>Standard attributes <a href="#alias">alias</a>, <a href="#comment">comment</a>, <a
                    href="#event-on-update-reading">event-on-update-reading</a>, <a
                    href="#event-on-change-reading">event-on-change-reading</a>, <a href="#room"
                    >room</a>, <a href="#eventMap">eventMap</a>, <a href="#loglevel">loglevel</a>,
                    <a href="#webCmd">webCmd</a></li>
        </ul>
        </ul>
=end html
=begin html_DE

<a name="Astro"></a>
<h3>Astro</h3>
<ul>
<a href="https://wiki.fhem.de/wiki/Modul_Astro">Deutsche Dokumentation im Wiki</a> vorhanden, die englische Version gibt es hier: <a href="commandref.html#Astro">Astro</a> 
</ul>
=end html_DE
=for :application/json;q=META.json 95_Astro.pm
{
  "author": [
    "Prof. Dr. Peter A. Henning <>"
  ],
  "x_fhem_maintainer": [
    "pahenning"
  ],
  "resources": {
    "x_wiki": {
      "web": "https://wiki.fhem.de/wiki/Modul_Astro"
    }
  },
  "keywords": [
    "astrology",
    "astronomy",
    "constellation",
    "date",
    "dawn",
    "dusk",
    "moon",
    "season",
    "sun",
    "star sign",
    "time",
    "twilight",
    "zodiac",
    "Astrologie",
    "Astronomie",
    "Datum",
    "Jahreszeit",
    "Mond",
    "Sonne",
    "Sternbild",
    "Sternzeichen",
    "Tierkreiszeichen",
    "Uhrzeit",
    "Zodiak"
  ],
  "prereqs": {
    "runtime": {
      "requires": {
        "Encode": 0,
        "GPUtils": 0,
        "Math::Trig": 0,
        "POSIX": 0,
        "Time::HiRes": 0,
        "Time::Local": 0,
        "strict": 0,
        "warnings": 0
      },
      "recommends": {
        "JSON": 0
      },
      "suggests": {
        "Cpanel::JSON::XS": 0,
        "JSON::XS": 0
      }
    }
  }
}
=end :application/json;q=META.json
=cut
