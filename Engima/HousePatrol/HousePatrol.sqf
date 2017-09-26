/*=========================================================================================== 
	Engima's House Patrol
	Remade by Engima
	Thanks to Tophe of Östgöta Ops [OOPS] for the original version!
	Original version: TypeSqf CPack Tophe.RandomHousePatrol.
=============================================================================================

HOW TO USE:
Place a unit anywhere on the map. Put a marker close to a house. Put this in the init field:  
_nil = [this, "theMarker"] execVM "Engima\HousePatrol\HousePatrol.sqf";

The unit will walk into the house that is nearest to the marker, and patrol it randomly. If 
the marker is moved to another house at any time, the unit will walk between the houses and 
start patrolling the new house instead.


OPTIONAL SETTINGS:

_nil = [this, MODE, STAND TIME, EXCLUDED POS, STARTING POS, STANCE, DEBUG] execVM "Tophe\HousePatrol\HousePatrol.sqf";

* BEHAVIOUR - set unit behaviour.
	guard = [this,"COMBAT"] execVM "Tophe\HousePatrol\HousePatrol.sqf" 
	
	Options: CARELESS, SAFE, AWARE, COMBAT, STEALTH
	Default: SAFE

* STAND TIME - Set maximum amount of seconds the unit will wait before moving to next waypoint.
	guard = [this,"SAFE",50] execVM "Tophe\HousePatrol\HousePatrol.sqf" 
		
	Options: Any value in seconds. 0 = continuous patrol.
	Default: 30

* EXCLUDED POSITIONS - exclude certain building positions from patrol route.
	guard = [this,"SAFE",30, [5,4]] execVM "Tophe\HousePatrol\HousePatrol.sqf" 
	
	Options: Array of building positions
	Default: [] (no excluded positions)
	
* STARTING POS - Some building positions doesn't work well will the setPos command. 
	Here you may add a custom starting pos. Negative number means starting pos will be randomized.
	guard = [this,"SAFE",30, [5,4], 2] execVM "Tophe\HousePatrol\HousePatrol.sqf" 

	Options: Any available building position
	Default: -1 (random)

* STANCE - Tell the unit what stance to use.
	To keep the unit from going prone you can set this to MIDDLE or UP.
	AUTO will be the standard behaviour and unit will crawl around in combat mode.
	HIGH is the default mode. This is like AUTO but prone position is excluded.
	
	Options: UP, DOWN, MIDDLE, AUTO, HIGH
	Default: HIGH
	
* DEBUG - Use markers and chatlog for mission design debugging.
	guard = [this,"SAFE",30, [], -1, true] execVM "Tophe\HousePatrol\HousePatrol.sqf" 	
	
	Options: true/false
	Default: false

===========================================================================================*/
private ["_fncFindNearestEnterableBuilding"];

// Finds all enterable buildings within a certain radius.
// _pos (Array): The center position of the area to check.
// _radius (Scalar): The radius of the area to check.
// _restrictedBuildings (Array): A list of house types to exclude.
_fncFindNearestEnterableBuilding = {
	params ["_pos", "_radius", ["_restrictedBuildings", []]];
	private _nearestEnterableBuilding = objNull;
	
	private _buildings = nearestObjects [_pos, ["house"], _radius];
	private _nearestDistance = _radius;

	{
		if ([_x, 1] call BIS_fnc_isBuildingEnterable && {!(typeof _x in _restrictedBuildings)}) then {
			if (_pos distance2D _x < _nearestDistance) then {
				_nearestDistance = _pos distance2D _x;
				_nearestEnterableBuilding = _x;
			};
		}
	} foreach _buildings;
	
	_nearestEnterableBuilding
};

params ["_unit", "_markerName", ["_behaviour", "SAFE"], ["_maxWaitTime", 30], ["_debug", false]];

private ["_position", "_house", "_numOfBuildingPos", "_currentBuildingPos", "_lastBuildingPos", "_waitTime", "_timeout"];
private ["_behaviours", "_name", "_i", "_arrow", "_text", "_marker"];

if (!local _unit) exitWith {};

_position = getPos _unit;
_numOfBuildingPos = 0;
_currentBuildingPos = 0;
_lastBuildingPos = 0;
_waitTime = 0;
_timeout = 0;

_behaviours = ["CARELESS", "SAFE", "AWARE", "COMBAT", "STEALTH"];
//_stances = ["UP", "DOWN", "MIDDLE", "AUTO", "HIGH"];

_name = vehicleVarName _unit;


if (isNil _name) then 
{
	_name = format["Guard x%1y%2", floor (_position select 0), floor (_position select 1)]
};

// Set behaviour of unit
if (_behaviour in _behaviours) then 
{
	_unit setBehaviour _behaviour;
} 
else 
{
	_unit setBehaviour "SAFE";
};

/*
// Set unit stance
if (_stance == "HIGH") then
{
	_stanceCheck = 
	{
		private ["_unit"];
	
		_unit = _this select 0;
		while {alive _unit} do 
		{
			if (unitPos _unit == "DOWN") then 
			{ 
				if (random 1 < 0.5) then {_unit setUnitPos "MIDDLE"} else {_unit setUnitPos "UP"};				
				sleep random 5;
				_unit setUnitPos "AUTO";
			};

		};
	};

	[_unit] spawn _stanceCheck;
}
else 
{
	if (_stance in _stances) then {
		_unit setUnitPos _stance;
	} 
	else {
		_unit setBehaviour "UP";
	};
};
*/

// Have unit patrol inside house
while {alive _unit} do
{
	// Get the house nearest the marker
	_house = [getMarkerPos _markerName, 50] call _fncFindNearestEnterableBuilding; //nearestBuilding _unit;
	
	// Find number of positions in building
	while {format ["%1", _house buildingPos _numOfBuildingPos] != "[0,0,0]"} do {
		_numOfBuildingPos = _numOfBuildingPos + 1;
	};
	
	// DEBUGGING - Mark house on map, mark building positions ingame, broadcast information
	if (_debug) then {
		for [{_i = 0}, {_i <= _numOfBuildingPos}, {_i = _i + 1}] do	{
			//if (!(_i in _excludedPositions)) then {	
				_arrow = "Sign_Arrow_F" createVehicle (_house buildingPos _i);
				_arrow setPos (_house buildingpos _i);
			//};
		};
		player globalChat format["%1 - Number of available positions: %2", _name, _numOfBuildingPos]; 
		
		_marker = createMarker [_name, position _unit];
		_marker setMarkerType "mil_dot";
		_marker setMarkerText _name;
		_marker setMarkerColor "ColorGreen";
	};
	
	// Get the next position.
	private _startingPos = floor(random _numOfBuildingPos);
	
	if (_startingPos > _numOfBuildingPos - 1) then {
		_startingPos = _numOfBuildingPos - 1
	};

	_currentBuildingPos = _lastBuildingPos;
	if (_numOfBuildingPos >= 2) then {
		while {_lastBuildingPos == _currentBuildingPos} do	{
			_currentBuildingPos = floor(random _numOfBuildingPos);
		};
	};
	
	private _buildingPos = _house buildingPos _currentBuildingPos;
	_unit doMove _buildingPos;
	_unit moveTo _buildingPos;
	(group _unit) setSpeedMode "LIMITED";
	
	_timeout = time + 500;
	waitUntil {sleep 5; _unit distance _buildingPos < 2 || moveToCompleted _unit || moveToFailed _unit || !alive _unit || _timeout < time};
	
	if (_timeout < time) then {
		_unit setPos (_house buildingPos _currentBuildingPos)
	};
	
	// DEBUGGING - move marker to new position
	if (_debug) then {
		_name setMarkerPos position _unit; 
		_text = format["%1: moving to pos %2", _name, _currentBuildingPos]; 
		_name setMarkerText _text;
	};
	
	_waitTime = floor random _maxWaitTime;
	sleep _waitTime;
	_lastBuildingPos = _currentBuildingPos;
};

// DEBUGGING - Change marker color if script ends
if (_debug) then {
	player globalChat format["%1 - ended house patrol loop", _name];
	_name setMarkerColor "ColorRed";
};