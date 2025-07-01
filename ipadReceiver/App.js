import React, { useEffect, useState } from 'react';
import { View, Text, Button, Image, Alert, Platform } from 'react-native';
import * as Clipboard from 'expo-clipboard';

export default function App() {
  const [clipboard, setClipboard] = useState({ type: 'text', data: '' });

  useEffect(() => {
    const ws = new WebSocket('ws://10.0.0.120:3000'); // Replace with your laptop's IP

    ws.onmessage = event => {
      try {
        const msg = JSON.parse(event.data);
        if (msg.type === 'clipboardUpdate') {
          setClipboard(msg.clipboard);
        }
      } catch (err) {
        console.error('WebSocket parse error:', err);
      }
    };

    ws.onerror = err => console.error('WebSocket error:', err);
    ws.onclose = () => console.log('WebSocket closed');

    return () => ws.close();
  }, []);

  const copyToClipboard = async () => {
    if (clipboard.type === 'text') {
      await Clipboard.setStringAsync(clipboard.data);
      Alert.alert('Copied text to clipboard');
    } else if (clipboard.type === 'image') {
      Alert.alert('Image copy not implemented yet');
      // Image copy support on iOS requires `react-native-clipboard-image` or native modules.
    }
  };

  return (
    <View style={{ flex: 1, padding: 40, justifyContent: 'center', alignItems: 'center' }}>
      <Text style={{ marginBottom: 20, fontSize: 20 }}>
        {clipboard.type === 'text' ? clipboard.data : '[Image]'}
      </Text>

      {clipboard.type === 'image' && (
        <Image
          source={{ uri: clipboard.data }}
          style={{ width: 200, height: 200, marginBottom: 20 }}
          resizeMode="contain"
        />
      )}

      <Button title="Copy to Clipboard" onPress={copyToClipboard} />
    </View>
  );
}
