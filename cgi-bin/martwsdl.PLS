<?xml version="1.0" encoding="UTF-8"?>
<!-- Published by Syed Haider -->
<definitions 
	name="BioMartSoapService" 
	targetNamespace="http://[TAG:server_host]:[TAG:server_port]/MartServiceSoap"
	xmlns="http://schemas.xmlsoap.org/wsdl/"
	xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"	
	xmlns:tns="http://[TAG:server_host]:[TAG:server_port]/MartServiceSoap"
	xmlns:xsd="http://www.w3.org/2001/XMLSchema"
	xmlns:sawsdl="http://www.w3.org/ns/sawsdl"
	>


<types>
	<xsd:schema>
		<xsd:import namespace="http://[TAG:server_host]:[TAG:server_port]/MartServiceSoap"
				schemaLocation="martxsd" />		
	</xsd:schema>
</types>

<!-- getRegistry -->
<message name="getRegistry">
	<part name="parameters" element="tns:getRegistry"/>
</message>
<message name="getRegistryResponse">
	<part name="parameters" element="tns:getRegistryResponse"/>
</message>

<!-- getDatasets -->
<message name="getDatasets">
	<part name="parameters" element="tns:getDatasets"/>
</message>
<message name="getDatasetsResponse">
	<part name="parameters" element="tns:getDatasetsResponse"/>
</message>

<!-- getAttributes -->
<message name="getAttributes">
	<part name="parameters" element="tns:getAttributes"/>
</message>
<message name="getAttributesResponse">
	<part name="parameters" element="tns:getAttributesResponse"/>
</message>

<!-- getFilters -->
<message name="getFilters">
	<part name="parameters" element="tns:getFilters"/>
</message>
<message name="getFiltersResponse">
	<part name="parameters" element="tns:getFiltersResponse"/>
</message>

<!-- query -->
<message name="query">
	<part name="parameters" element="tns:query"/>
</message>
<message name="queryResponse">
	<part name="parameters" element="tns:queryResponse"/>
</message>

<!-- BioMartException-->
<message name="BioMartException">
	<part name="fault" element="tns:BioMartException"/>
</message>

<!--TODO: automatic addition of operations if ontology terms are present in settings.conf -->
[TAG:IF_ONTOLOGY_TERMS_MESSAGE]

<portType name="MartServiceSoap">
	<operation name="getRegistry">
		<input message="tns:getRegistry"></input>
		<output message="tns:getRegistryResponse"></output>
		<fault message="tns:BioMartException" name="BioMartException"></fault>
	</operation>
	
	<operation name="getDatasets">
		<input message="tns:getDatasets"></input>
		<output message="tns:getDatasetsResponse"></output>
		<fault message="tns:BioMartException" name="BioMartException"></fault>
	</operation>

	<operation name="getAttributes">
		<input message="tns:getAttributes"></input>
		<output message="tns:getAttributesResponse"></output>
		<fault message="tns:BioMartException" name="BioMartException"></fault>
	</operation>

	<operation name="getFilters">
		<input message="tns:getFilters"></input>
		<output message="tns:getFiltersResponse"></output>
		<fault message="tns:BioMartException" name="BioMartException"></fault>
	</operation>

	<operation name="query">
		<input message="tns:query"></input>
		<output message="tns:queryResponse"></output>
		<fault message="tns:BioMartException" name="BioMartException"></fault>
	</operation>

	<!-- TODO: automatic addition of operations if ontology terms are present in settings.conf -->
	[TAG:IF_ONTOLOGY_TERMS_PORTTYPE]
	
</portType>


<!-- binding type should  point to the name of portType -->

<binding name="BioMartSoapBinding" type="tns:MartServiceSoap">
	<soap:binding transport="http://schemas.xmlsoap.org/soap/http" style="document"></soap:binding>
	<operation name="getRegistry">
		<!-- soapAction not required -->
		<soap:operation soapAction=""></soap:operation>
		<input>
			<soap:body use="literal"></soap:body>
		</input>
		<output>
			<soap:body use="literal"></soap:body>
		</output>
		<fault name="BioMartException">
			<soap:fault name="BioMartException" use="literal"/>
		</fault>
	</operation>

	<operation name="getDatasets">
		<!-- soapAction not required -->
		<soap:operation soapAction=""></soap:operation>
		<input>
			<soap:body use="literal"></soap:body>
		</input>
		<output>
			<soap:body use="literal"></soap:body>
		</output>
		<fault name="BioMartException">
			<soap:fault name="BioMartException" use="literal"/>
		</fault>
	</operation>

	<operation name="getAttributes">
		<!-- soapAction not required -->
		<soap:operation soapAction=""></soap:operation>
		<input>
			<soap:body use="literal"></soap:body>
		</input>
		<output>
			<soap:body use="literal"></soap:body>
		</output>
		<fault name="BioMartException">
			<soap:fault name="BioMartException" use="literal"/>
		</fault>
	</operation>

	<operation name="getFilters">
		<!-- soapAction not required -->
		<soap:operation soapAction=""></soap:operation>
		<input>
			<soap:body use="literal"></soap:body>
		</input>
		<output>
			<soap:body use="literal"></soap:body>
		</output>
		<fault name="BioMartException">
			<soap:fault name="BioMartException" use="literal"/>
		</fault>
	</operation>
	
	<operation name="query">
		<!-- soapAction not required -->
		<soap:operation soapAction=""></soap:operation>
		<input>
			<soap:body use="literal"></soap:body>
		</input>
		<output>
			<soap:body use="literal"></soap:body>
		</output>
		<fault name="BioMartException">
			<soap:fault name="BioMartException" use="literal"/>
		</fault>
	</operation>


	<!-- TODO: automatic addition of operations if ontology terms are present in settings.conf -->
	[TAG:IF_ONTOLOGY_TERMS_OPERATION]
</binding>

	<service name="BioMartSoapService">
        <documentation>BioMart Soap Based Webservice version 0.1</documentation>
        <port name="BioMartSoapPort" binding="tns:BioMartSoapBinding">
           <soap:address location="http://[TAG:server_host]:[TAG:server_port]/[TAG:cgiLocation]/martsoap"/>
        </port>
    </service>
</definitions>
