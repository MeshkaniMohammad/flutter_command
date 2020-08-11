import 'package:flutter/material.dart';

import 'weather_viewmodel.dart';

class WeatherListView extends StatelessWidget {
  final List<WeatherEntry> data;
  WeatherListView(this.data);
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: data.length,
      itemBuilder: (BuildContext context, int index) => ListTile(
        title: Text(data[index].cityName),
        subtitle: Text(data[index].description),
        leading: Image.network(
          data[index].iconURL,
          frameBuilder: (BuildContext context, Widget child, int frame,
              bool wasSynchronouslyLoaded) {
            return child;
          },
          loadingBuilder: (BuildContext context, Widget child,
              ImageChunkEvent loadingProgress) {
            if (loadingProgress == null) return child;
            return CircularProgressIndicator();
          },
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.error,
            size: 40,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${data[index].temperature}°C'),
            Text('${data[index].wind}km/h'),
          ],
        ),
      ),
    );
  }
}
