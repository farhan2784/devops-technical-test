--DevOps Technical Test App using containerization 

The Multistage Containerization strategy is used to create a production-grade container, result in faster deployment, smaller image size and improved container security.

--Project Structure: 

Porject-Folder: 
  |
  |___________Dockerfile
  |
  |___________Server.js
  |
  |___________package.json


--Buil & Run

# Docker build -t docker-test . 


# Docker run -d -p 8888:80 --name devops-test docker-test:latest


--Test

curl http://localhost:8888/hello
 