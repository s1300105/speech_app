import "package:flutter/material.dart";

ElevatedButton createElevatedButton({
  required IconData icon,
  required Color iconColor,
  required VoidCallback onPressFunc
}) {
  return ElevatedButton.icon(
    style: ElevatedButton.styleFrom(
      padding: EdgeInsets.all(6.0),
      side: BorderSide(
        color: Colors.red,
        width: 4.0
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      backgroundColor: Colors.white,
      elevation: 9.0,
    ),
    onPressed: onPressFunc,
    icon: Icon(
      icon,
      color: iconColor,
      size: 38.0,
    ),
    label: Text(''),
  );
}