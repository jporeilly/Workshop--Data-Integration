
# coding: utf-8

# In[ ]:


#import modules that will assist in working with local filesystem to get to PDI Data Service Client Jars
import os
from os import listdir
from os.path import isfile, join
import pandas as pd


# In[ ]:


#Create a variable and assign the path of the pdi-dataservice-client folder within your Pentaho installation
#and another variable to store path and name of all of the required PDI Data Service Client Jar files
jdbc_dir="/opt/pentaho/design-tools/data-integration/Data Service JDBC Driver/pdi-dataservice-client"
jdbc_jars=['{}/{}'.format(jdbc_dir, f) for f in listdir(jdbc_dir) if isfile(join(jdbc_dir, f))]


# In[ ]:


#Call the CLASSPATH environment variable, if does not exist create the envrionment variable
os.environ['CLASSPATH'] = ""
javapath = os.environ['CLASSPATH']
for x in jdbc_jars:
    javapath+= ':' + x
    
os.environ['CLASSPATH'] = javapath
print(os.environ['CLASSPATH'])
import jaydebeapi


# In[ ]:


conn = jaydebeapi.connect(jclassname="org.pentaho.di.trans.dataservice.jdbc.ThinDriver",
url = "jdbc:pdi://localhost:8080/kettle?webappname=pentaho", driver_args= ['admin', 'password'],jars=jdbc_jars)


# In[ ]:


curs = conn.cursor()
curs.execute("SELECT * FROM PDI_Data_Service_JupyterNotebook")
cols = [desc[0] for desc in curs.description]
records = curs.fetchall()


# In[ ]:


df = pd.DataFrame(records, columns = cols)


# In[ ]:


df


# In[ ]:


# learn a scikit-learn classifier
import pandas as pd
import numpy as np
from sklearn.tree import DecisionTreeClassifier
from sklearn import tree
from sklearn.externals import joblib
import os


# extract training columns and class column
X=df.iloc[:,[2,3,4]].values
Y=df.iloc[:,[5]].values

print(X)
print(Y)





# In[ ]:


# build a decision tree

dt = tree.DecisionTreeClassifier(class_weight=None, criterion='gini', max_depth=None,
            max_features=None, max_leaf_nodes=None,
            min_impurity_decrease=0.0, min_impurity_split=None,
            min_samples_leaf=1, min_samples_split=2,
            min_weight_fraction_leaf=0.0, presort=False, random_state=None,
            splitter='best')

dt.fit(X,Y)





# In[ ]:


#mke a temp, pressure and rpm failure prediction

#temp failure > 150
prediction = dt.predict([[151, 500,1406]]) 
print(prediction) 

#pressure failure > 600
prediction = dt.predict([[145, 601,1406]]) 
print(prediction) 

#rpm failure predction > 1500
prediction = dt.predict([[140, 500,1502]]) 
print(prediction) 

#no failure prediction
prediction = dt.predict([[140, 450,1402]]) 
print(prediction) 


# In[ ]:


import graphviz 
import pydotplus
import collections

# Visualize data
data_feature_names = [ 'temperature', 'pressure', 'rpm' ]
dot_data = tree.export_graphviz(dt,
                                feature_names=data_feature_names,
                                out_file=None,
                                filled=True,
                                rounded=True)
graph = pydotplus.graph_from_dot_data(dot_data)

colors = ('turquoise', 'orange')
edges = collections.defaultdict(list)

for edge in graph.get_edge_list():
    edges[edge.get_source()].append(int(edge.get_destination()))

for edge in edges:
    edges[edge].sort()    
    for i in range(2):
        dest = graph.get_node(str(edges[edge][i]))[0]
        dest.set_fillcolor(colors[i])

graph.write_png('/home/demouser/tree.png')


# In[ ]:


from IPython.display import Image
Image('/home/demouser/tree.png')


# In[ ]:


#Next step can be to utilize model management via outputting model to file

# save the model
filename='file:///home/demouser/utils/JupyterNotebook/decisiontreeclassifier_jupyter.model'
joblib.dump(dt,filename)

