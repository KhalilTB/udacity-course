// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import 'package:unit_converter/api.dart';
import 'package:unit_converter/category.dart';
import 'package:unit_converter/unit.dart';

const _padding = EdgeInsets.all(16.0);

/// [UnitConverter] where users can input amounts to convert in one unit
/// and retrieve the conversion in another unit
class UnitConverter extends StatefulWidget {
  final Category category;

  /// This [UnitConverter] handles [Unit]s for a specific [Category].
  const UnitConverter({
    @required this.category,
  }) : assert(category != null);

  @override
  _UnitConverterState createState() => _UnitConverterState();
}

class _UnitConverterState extends State<UnitConverter> {
  final _inputKey = GlobalKey(debugLabel: 'inputText');
  Unit _fromValue;
  Unit _toValue;
  double _inputValue;
  String _convertedValue = '';
  bool _showErrorUI = false;
  bool _showValidationError = false;

  Future<Null> _updateConversion() async {
    // Our API has a handy convert function, so we can use that for
    // the Currency [Category]
    if (widget.category.name == apiCategory['name']) {
      final api = Api();
      final conversion = await api.convert(apiCategory['route'],
          _inputValue.toString(), _fromValue.name, _toValue.name);
      // API error or not connected to the internet
      if (conversion == null) {
        setState(() {
          _showErrorUI = true;
        });
        return;
      }
      setState(() {
        _convertedValue = _format(conversion);
      });
    } else {
      // For the static units, we do the conversion ourselves
      setState(() {
        _convertedValue = _format(
            _inputValue * (_toValue.conversion / _fromValue.conversion));
      });
    }
  }

  /// Clean up conversion; trim trailing zeros, e.g. 5.500 -> 5.5, 10.0 -> 10
  String _format(double conversion) {
    var outputNum = conversion.toStringAsPrecision(7);
    if (outputNum.contains('.') && outputNum.endsWith('0')) {
      var i = outputNum.length - 1;
      while (outputNum[i] == '0') {
        i -= 1;
      }
      outputNum = outputNum.substring(0, i + 1);
    }
    if (outputNum.endsWith('.')) {
      return outputNum.substring(0, outputNum.length - 1);
    }
    return outputNum;
  }

  void _updateInputValue(String input) {
    setState(() {
      if (input == null || input.isEmpty) {
        _convertedValue = '';
      } else {
        // Even though we are using the numerical keyboard, we still have to check
        // for non-numerical input such as '5..0' or '6 -3'
        try {
          final inputDouble = double.parse(input);
          _showValidationError = false;
          _inputValue = inputDouble;
          _updateConversion();
        } on Exception catch (e) {
          print('Error: $e');
          _showValidationError = true;
        }
      }
    });
  }

  Unit _getUnit(String unitName) {
    return widget.category.units.firstWhere(
      (Unit unit) {
        return unit.name == unitName;
      },
      orElse: null,
    );
  }

  void _updateFromConversion(dynamic unitName) {
    setState(() {
      _fromValue = _getUnit(unitName);
    });
    if (_inputValue != null) {
      _updateConversion();
    }
  }

  void _updateToConversion(dynamic unitName) {
    setState(() {
      _toValue = _getUnit(unitName);
    });
    if (_inputValue != null) {
      _updateConversion();
    }
  }

  Widget _createDropdown(String name, List<DropdownMenuItem> units,
      ValueChanged<dynamic> onChanged) {
    return Container(
      margin: EdgeInsets.only(top: 16.0),
      decoration: BoxDecoration(
        // This sets the color of the [DropdownButton] itself
        color: Colors.grey[50],
        border: Border.all(
          color: Colors.grey[400],
          width: 1.0,
        ),
      ),
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: Theme(
        // This sets the color of the [DropdownMenuItem]
        data: Theme.of(context).copyWith(
              canvasColor: Colors.grey[50],
            ),
        child: DropdownButtonHideUnderline(
          child: ButtonTheme(
            alignedDropdown: true,
            child: DropdownButton(
              value: name,
              items: units,
              onChanged: onChanged,
              style: Theme.of(context).textTheme.title,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.category.units == null ||
        (widget.category.name == apiCategory['name'] && _showErrorUI)) {
      return SingleChildScrollView(
        child: Container(
          margin: _padding,
          padding: _padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.0),
            color: widget.category.color['error'],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 180.0,
                color: Colors.white,
              ),
              Text(
                "Oh no! We can't connect right now!",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headline.copyWith(
                      color: Colors.white,
                    ),
              ),
            ],
          ),
        ),
      );
    }
    final units = <DropdownMenuItem>[];
    for (var unit in widget.category.units) {
      units.add(DropdownMenuItem(
        value: unit.name,
        child: Container(
          child: Text(
            unit.name,
            softWrap: true,
          ),
        ),
      ));
    }

    // Update the `from` [DropdownMenuItem] when we switch [Categories]
    if (_fromValue == null ||
        !(units.any((unit) {
          return unit.value == _fromValue.name;
        }))) {
      setState(() {
        _fromValue = widget.category.units[0];
      });
    }

    // Update the `to` [DropdownMenuItem] when we switch [Categories]
    if (_toValue == null ||
        !(units.any((unit) {
          return unit.value == _toValue.name;
        }))) {
      setState(() {
        _toValue = widget.category.units[1];
      });

      // Likewise, update the Output when we switch [Categories]
      if (_inputValue != null) {
        setState(() {
          _updateConversion();
        });
      }
    }

    final input = Padding(
      padding: _padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // This is the widget that accepts text input. In this case, it
          // accepts numbers and calls the onChanged property on update.
          // You can read more about it here: https://flutter.io/text-input
          TextField(
            key: _inputKey,
            style: Theme.of(context).textTheme.display1,
            decoration: InputDecoration(
              labelStyle: Theme.of(context).textTheme.display1,
              errorText: _showValidationError ? 'Invalid number entered' : null,
              labelText: 'Input',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(0.0),
              ),
            ),
            // Since we only want numerical input, we use a number keyboard. There
            // are also other keyboards for dates, emails, phone numbers, etc.
            keyboardType: TextInputType.number,
            onChanged: _updateInputValue,
          ),
          _createDropdown(_fromValue.name, units, _updateFromConversion),
        ],
      ),
    );

    final arrows = RotatedBox(
      quarterTurns: 1,
      child: Icon(
        Icons.compare_arrows,
        size: 40.0,
      ),
    );

    final output = Padding(
      padding: _padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InputDecorator(
            child: Text(
              _convertedValue,
              style: Theme.of(context).textTheme.display1,
            ),
            decoration: InputDecoration(
              labelText: 'Output',
              labelStyle: Theme.of(context).textTheme.display1,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(0.0),
              ),
            ),
          ),
          _createDropdown(_toValue.name, units, _updateToConversion),
        ],
      ),
    );

    final converter = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        input,
        arrows,
        output,
      ],
    );

    // Based on the orientation of the parent widget, figure out how to best
    // lay out our converter.
    return Padding(
      padding: _padding,
      child: OrientationBuilder(
        builder: (BuildContext context, Orientation orientation) {
          if (orientation == Orientation.portrait) {
            return SingleChildScrollView(
              child: converter,
            );
          } else {
            return SingleChildScrollView(
              child: Center(
                child: Container(
                  width: 450.0,
                  child: converter,
                ),
              ),
            );
          }
        },
      ),
    );
  }
}
