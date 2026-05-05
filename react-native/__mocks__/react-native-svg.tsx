import { Text, type TextProps } from 'react-native';

type SvgXmlProps = TextProps & { xml: string };

export const SvgXml = ({ xml: _xml, ...rest }: SvgXmlProps) => (
  <Text {...rest} />
);
